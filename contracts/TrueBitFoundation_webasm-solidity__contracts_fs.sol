pragma solidity ^0.4.16;

interface Consumer {
   function consume(bytes32 id, bytes32[] dta) public;
}

/* Calculate a merkle tree in solidity */

/**
* @title Calculate a merkle tree for the filesystem in solidity
* @author Sami Mäkelä
*/
contract Filesystem {
   bytes32[] zero;
   struct File {
     uint bytesize;
     bytes32[] data;
     string name;
     
     string ipfs_hash;
     bytes32 root;
   }
   mapping (bytes32 => File) files;
   function Filesystem() public {
      zero.length = 20;
      zero[0] = bytes32(0);
      for (uint i = 1; i < zero.length; i++) {
         zero[i] = keccak256(zero[i-1], zero[i-1]);
      }
   }
   
   function createFileWithContents(string name, uint nonce, bytes32[] arr, uint sz) public returns (bytes32) {
      bytes32 id = keccak256(msg.sender, nonce);
      File storage f = files[id];
      f.data = arr;
      f.name = name;
      setByteSize(id, sz);
      uint size = 0;
      uint tmp = arr.length;
      while (tmp > 1) { size++; tmp = tmp/2; }
      f.root = fileMerkle(arr, 0, size);
      return id;
   }

   function calcId(uint nonce) public view returns (bytes32) {
         return keccak256(msg.sender, nonce);
   }

   // the IPFS file should have same contents and name
   function addIPFSFile(string name, uint size, string hash, bytes32 root, uint nonce) public returns (bytes32) {
      bytes32 id = keccak256(msg.sender, nonce);
      File storage f = files[id];
      f.bytesize = size;
      f.name = name;
      f.ipfs_hash = hash;
      f.root = root;
      return id;
   }

   function getName(bytes32 id) public view returns (string) {
      return files[id].name;
   }
   
   function getNameHash(bytes32 id) public view returns (bytes32) {
      return hashName(files[id].name);
   }
   
   function getHash(bytes32 id) public view returns (string) {
      return files[id].ipfs_hash;
   }

   function getByteSize(bytes32 id) public view returns (uint) {
      return files[id].bytesize;
   }

   function setByteSize(bytes32 id, uint sz) public returns (uint) {
      files[id].bytesize = sz;
   }

   function getData(bytes32 id) public view returns (bytes32[]) {
      File storage f = files[id];
      return f.data;
   }

   function forwardData(bytes32 id, address a) public {
      File storage f = files[id];
      Consumer(a).consume(id, f.data);
   }
   
   function getRoot(bytes32 id) public view returns (bytes32) {
      File storage f = files[id];
      return f.root;
   }
   function getLeaf(bytes32 id, uint loc) public view returns (bytes32) {
      File storage f = files[id];
      return f.data[loc];
   }

   // Methods to build IO blocks
   struct Bundle {
      bytes32 name_file;
      bytes32 data_file;
      bytes32 size_file;
      uint pointer;
      address code;
      string code_file;
      bytes32 init;
      bytes32[] files;
   }

   mapping (bytes32 => Bundle) bundles;

   function makeSimpleBundle(uint num, address code, bytes32 code_init, bytes32 file_id) public returns (bytes32) {
       bytes32 id = keccak256(msg.sender, num);
       Bundle storage b = bundles[id];
       b.code = code;

       bytes32 res1 = bytes32(getByteSize(file_id));
       for (uint i = 0; i < 3; i++) res1 = keccak256(res1, zero[i]);
       
       bytes32 res2 = hashName(getName(file_id));
       for (i = 0; i < 3; i++) res2 = keccak256(res2, zero[i]);
       
       bytes32 res3 = getRoot(file_id);
       for (i = 0; i < 3; i++) res3 = keccak256(res3, zero[i]);
       
       b.init = keccak256(code_init, res1, res2, res3);

       b.files.push(file_id);

       return id;
   }
   
   bytes32 empty_file = 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563;

   function finalizeBundleIPFS(bytes32 id, string file, bytes32 init) public {
       Bundle storage b = bundles[id];
       bytes32[] memory res1 = new bytes32[](b.files.length);
       bytes32[] memory res2 = new bytes32[](b.files.length);
       bytes32[] memory res3 = new bytes32[](b.files.length);
       
       for (uint i = 0; i < b.files.length; i++) {
          res1[i] = bytes32(getByteSize(b.files[i]));
          res2[i] = hashName(getName(b.files[i]));
          res3[i] = getRoot(b.files[i]);
       }
       
       b.code_file = file;
       
       b.init = keccak256(init, calcMerkle(res1, 0, 10), calcMerkle(res2, 0, 10), calcMerkleDefault(res3, 0, 10, empty_file));
   }
   
   function debug_finalizeBundleIPFS(bytes32 id, string file, bytes32 init) public returns (bytes32, bytes32, bytes32, bytes32, bytes32) {
       Bundle storage b = bundles[id];
       bytes32[] memory res1 = new bytes32[](b.files.length);
       bytes32[] memory res2 = new bytes32[](b.files.length);
       bytes32[] memory res3 = new bytes32[](b.files.length);
       
       for (uint i = 0; i < b.files.length; i++) {
          res1[i] = bytes32(getByteSize(b.files[i]));
          res2[i] = hashName(getName(b.files[i]));
          res3[i] = getRoot(b.files[i]);
       }
       
       b.code_file = file;
       
       return (init, calcMerkle(res1, 0, 10), calcMerkle(res2, 0, 10), calcMerkleDefault(res3, 0, 4, empty_file),
               keccak256(init, calcMerkle(res1, 0, 10), calcMerkle(res2, 0, 4), calcMerkleDefault(res3, 0, 4, empty_file)));
   }
   
   function makeBundle(uint num) public view returns (bytes32) {
       bytes32 id = keccak256(msg.sender, num);
       return id;
   }

   function addToBundle(bytes32 id, bytes32 file_id) public returns (bytes32) {
       Bundle storage b = bundles[id];
       b.files.push(file_id);
   }
   
   function getInitHash(bytes32 bid) public view returns (bytes32) {
       Bundle storage b = bundles[bid];
       return b.init;
   }
   
   function getCode(bytes32 bid) public view returns (bytes) {
       Bundle storage b = bundles[bid];
       return getCodeAtAddress(b.code);
   }
   
   function getIPFSCode(bytes32 bid) public view returns (string) {
       Bundle storage b = bundles[bid];
       return b.code_file;
   }
   
   function getFiles(bytes32 bid) public view returns (bytes32[]) {
       Bundle storage b = bundles[bid];
       return b.files;
   }
   
   function getCodeAtAddress(address a) internal view returns (bytes) {
        uint len;
        assembly {
            len := extcodesize(a)
        }
        bytes memory bs = new bytes(len);
        assembly {
            extcodecopy(a, add(bs,32), 0, len)
        }
        return bs;
   }

   function makeMerkle(bytes arr, uint idx, uint level) internal pure returns (bytes32) {
      if (level == 0) return idx < arr.length ? bytes32(uint(arr[idx])) : bytes32(0);
      else return keccak256(makeMerkle(arr, idx, level-1), makeMerkle(arr, idx+(2**(level-1)), level-1));
   }

   function calcMerkle(bytes32[] arr, uint idx, uint level) internal returns (bytes32) {
      if (level == 0) return idx < arr.length ? arr[idx] : bytes32(0);
      else return keccak256(calcMerkle(arr, idx, level-1), calcMerkle(arr, idx+(2**(level-1)), level-1));
   }

   function fileMerkle(bytes32[] arr, uint idx, uint level) internal returns (bytes32) {
      if (level == 0) return idx < arr.length ? keccak256(bytes16(arr[idx]), uint128(arr[idx])) : keccak256(bytes16(0), bytes16(0));
      else return keccak256(fileMerkle(arr, idx, level-1), fileMerkle(arr, idx+(2**(level-1)), level-1));
   }

   function calcMerkleDefault(bytes32[] arr, uint idx, uint level, bytes32 def) internal returns (bytes32) {
      if (level == 0) return idx < arr.length ? arr[idx] : def;
      else return keccak256(calcMerkleDefault(arr, idx, level-1, def), calcMerkleDefault(arr, idx+(2**(level-1)), level-1, def));
   }

   // assume 256 bytes?
   function hashName(string name) public pure returns (bytes32) {
      return makeMerkle(bytes(name), 0, 8);
   }

}

