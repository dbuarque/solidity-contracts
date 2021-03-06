pragma solidity ^0.4.18;

/*
 * A minimum multisig wallet interface. Compatible with MultiSigWallet by Gnosis.
 */
contract WalletBasic {
    function isOwner(address owner) public returns (bool);
}

/**
 * @dev MultiOwnable contract.
 */
contract MultiOwnable {
    
    WalletBasic public wallet;
    
    event MultiOwnableWalletSet(address indexed _contract, address indexed _wallet);

    function MultiOwnable 
        (address _wallet)
        public
    {
        wallet = WalletBasic(_wallet);
        MultiOwnableWalletSet(this, wallet);
    }

    /** Check if a caller is the MultiSig wallet. */
    modifier onlyWallet() {
        require(wallet == msg.sender);
        _;
    }

    /** Check if a caller is one of the current owners of the MultiSig wallet or the wallet itself. */
    modifier onlyOwner() {
        require (isOwner(msg.sender));
        _;
    }

    function isOwner(address _address) 
        public
        constant
        returns(bool)
    {
        // NB due to lazy eval wallet could be a normal address and isOwner won't be called if the first condition is met
        return wallet == _address || wallet.isOwner(_address);
    }


    /* PAUSABLE with upause callable only by wallet */ 

    bool public paused = false;

    event Pause();
    event Unpause();

    /**
    * @dev Modifier to make a function callable only when the contract is not paused.
    */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /**
    * @dev Modifier to make a function callable only when the contract is paused.
    */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
    * @dev called by any MSW owner to pause, triggers stopped state
    */
    function pause() 
        onlyOwner
        whenNotPaused 
        public 
    {
        paused = true;
        Pause();
    }

    /**
    * @dev called by the MSW (all owners) to unpause, returns to normal state
    */
    function unpause() 
        onlyWallet
        whenPaused
        public
    {
        paused = false;
        Unpause();
    }
}
