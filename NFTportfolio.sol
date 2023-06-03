// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DragonBallz is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable {
    
    // Struct details of Premium Users
    struct premiumUsers{
        string userType;
        uint mintingLimit;
        address userAddress;
        bool isRegistered;
        bool isVerified;
    }
    

    // Struct details of Normal Users
    struct normalUsers{
        string userType;
        uint mintingLimit;
        address userAddress;
        bool isRegistered;
    }


    // Struct details of Phase
    struct phase {
        uint256 reservedLimit;
        bool isActivate;
        uint256 premiumUserLimit;
        uint256 NormalUserLimit;
        mapping(address => uint256) premiumUserBalance;
        mapping(address => uint256) normalUserBalance;
    }

    // Struct details of bulkNFTs
    struct bulkNfts{
        uint tokenId;
        string uri;
    }

    

    mapping(address => premiumUsers) public PremiumUsersMapping;
    mapping(address => normalUsers) public NormalUsersMapping;
    mapping(uint => phase) public phaseMapping;
    mapping(address => bool) adminMapping;
    


    //state Variables
    uint256 public maxMintingLimit;
    uint256 public platformMintingLimit;
    uint256 public UserMintingLimit;
    uint256 public premuinGLimit;
    uint256 public NormalGLimit;
    uint256 public currentPhase;
    bool isTransferable;


    event UserRegistered(address _address, string _UserType);
    event PremiumUserVerified(address _address);
    event PhaseCreated(uint256 _PhaseReservedLim, uint256 _premiumUserLimit, uint256 _NormalUserLimit);
    event HashUpdated(bulkNfts[] hashData);
    event PhaseLimitUpdated(uint newLimit);



    /*
      @dev Constructor function to declare minting limits.
      Requirement:
      This function can be called by deployer
      @param _maxMintingLimit  
      @param _platformMintingLimit 
    */
    constructor(uint256 _maxMintingLimit, uint256 _platformMintingLimit) ERC721("DragonBallz", "DBZ") {
        require(_maxMintingLimit >= _platformMintingLimit, "Invalid Minting limit");
        maxMintingLimit = _maxMintingLimit;
        platformMintingLimit = _platformMintingLimit;
        UserMintingLimit = _maxMintingLimit - _platformMintingLimit;
    }
    

    

    /*
        @dev registerUser is used to register Users.
        Requirement:
        This function can be called by anyone
        @param _userAddress,
        @param _mintingLimit,
        @param _userType

        Emits UserRegistered(_userAddress, _userType);
    */
    function registerUser(address _userAddress, uint _mintingLimit, string memory _userType ) public onlyOwner{
        require(_userAddress != address(0), "Invalid Address");
        require(PremiumUsersMapping[_userAddress].userAddress == address(0) && NormalUsersMapping[_userAddress].userAddress == address(0), "User already registered..!");

        if(keccak256(abi.encodePacked(_userType)) ==  keccak256(abi.encodePacked("premium"))) {
            //Register as premium user
            PremiumUsersMapping[_userAddress] = premiumUsers(_userType, _mintingLimit, _userAddress, true, false);

        } else if(keccak256(abi.encodePacked(_userType)) == keccak256(abi.encodePacked("normal"))) {
            //Register as normal user
            NormalUsersMapping[_userAddress] = normalUsers(_userType, _mintingLimit, _userAddress, true);

        }else if(keccak256(abi.encodePacked(_userType)) == keccak256(abi.encodePacked("admin"))){
            adminMapping[_userAddress] = true;

        } else{
            revert ("Invalid user role");
        }

        emit UserRegistered(_userAddress, _userType);
    }


    /*
        @dev verifyPremiumUser is used to verify Premium Users .
        Requirement:
        This function can be called by onlyOwner
        @param _userAddress

     
        Emits PremiumUserVerified( _userAddress);
    */
    function verifyPremiumUser(address _userAddress) public onlyOwner {
        require(PremiumUsersMapping[_userAddress].userAddress != address(0), "Invalid User Address");
        require(PremiumUsersMapping[_userAddress].isVerified == false,"User already verified");

        PremiumUsersMapping[_userAddress].isVerified = true;

        emit PremiumUserVerified( _userAddress);
    }

    /*
        @dev createPhase is used to Create Phase.
        Requirement:
        This function can be called by onlyOwner
        @param _PhaseReservedLim,
        @param _premiumUserLimit,
        @param _NormalUserLimit
     
        Emits PhaseCreated( _PhaseReservedLim, _premiumUserLimit, _NormalUserLimit);
    */
    function createPhase(uint256 _PhaseReservedLim, uint256 _premiumUserLimit, uint256 _NormalUserLimit) public onlyOwner{
        require(phaseMapping[currentPhase].isActivate == false, "Phase is already active");
        require(_PhaseReservedLim < UserMintingLimit, "Limit exceed");
        require(phaseMapping[currentPhase].reservedLimit == 0, "Phase already created");
        
        phaseMapping[currentPhase].reservedLimit = _PhaseReservedLim;
        phaseMapping[currentPhase].premiumUserLimit = _premiumUserLimit;
        phaseMapping[currentPhase].NormalUserLimit = _NormalUserLimit;

        emit PhaseCreated( _PhaseReservedLim, _premiumUserLimit, _NormalUserLimit);
    }   

    /*
        @dev activatePhase is used to activate the created phase.
        Requirement:
        This function can be called by onlyOwner
    */
    function activatePhase() public onlyOwner{
        require(phaseMapping[currentPhase].isActivate == false, "Phase is already active");
        require(phaseMapping[currentPhase].premiumUserLimit != 0, "Phase not created");
        phaseMapping[currentPhase].isActivate = true;
    }

    /*
        @dev deActivatePhase is used to Deactivate the created phase.
        Requirement:
        This function can be called by onlyOwner
    */
    function deActivatePhase() public onlyOwner{
        require(phaseMapping[currentPhase].isActivate == true,"Phase is not activated yet..!");
        require(phaseMapping[currentPhase].premiumUserLimit != 0, "Phase not created");
        
        phaseMapping[currentPhase].isActivate = false;
        currentPhase++;
    }


    /*
        @dev SafeMint is used to Mint NFTs.
        Requirement:
        This function can be called by Registered or verified Users.
        @param to,
        @param tokenId,
        @param uri

        Emits Transfer
    */
    function SafeMint(address to, uint tokenId, string memory uri) public  { 
        require(PremiumUsersMapping[msg.sender].isVerified == true || NormalUsersMapping[msg.sender].isRegistered == true,"You are not verified user");
        require(phaseMapping[currentPhase].isActivate == true,"Phase is not activated..!");
        require(UserMintingLimit > 0,"Limit Exceed");
        require(phaseMapping[currentPhase].reservedLimit > 0, "phase limit exceed");
    

        if(PremiumUsersMapping[msg.sender].isRegistered){
            require(PremiumUsersMapping[msg.sender].isVerified, "Premium User is not verified");
            require(balanceOf(msg.sender) < PremiumUsersMapping[msg.sender].mintingLimit,"Global limit exceed");
            require(phaseMapping[currentPhase].premiumUserLimit > phaseMapping[currentPhase].premiumUserBalance[msg.sender], "Phase user limit exceed");
            phaseMapping[currentPhase].premiumUserBalance[msg.sender]++;

        } else {
            require(balanceOf(msg.sender) < NormalUsersMapping[msg.sender].mintingLimit,"Global limit exceed");
            require(phaseMapping[currentPhase].NormalUserLimit >  phaseMapping[currentPhase].normalUserBalance[msg.sender], "Phase user limit exceed");
            phaseMapping[currentPhase].normalUserBalance[msg.sender]++;
        } 

        UserMintingLimit--;
        phaseMapping[currentPhase].reservedLimit--;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

    }

    /*
        @dev bulkMinting is used to mint NFTs in bulk.
        Requirement:
        This function can be called by Registered or verified Users.
        @param _uri,
        @param _tokenId,
        @param to
    */
    function bulkMinting(string[] memory _uri, uint[] memory _tokenId, address[] memory to) public {
        require(_uri.length == _tokenId.length && _tokenId.length == to.length, "Input length is not correct");
        require(PremiumUsersMapping[msg.sender].isVerified == true || NormalUsersMapping[msg.sender].isRegistered == true,"You are not registered or verified");
        require(phaseMapping[currentPhase].isActivate == true,"Phase is not activated..!");
        require(UserMintingLimit - _uri.length > 0,"Global user Limit Exceed");
        require(phaseMapping[currentPhase].reservedLimit - _uri.length > 0, "phase limit exceed");
        
        for (uint i = 0; i < _uri.length; i++){
            if(PremiumUsersMapping[msg.sender].isRegistered){
            require(PremiumUsersMapping[msg.sender].isVerified, "Premium User is not verified");
            require(balanceOf(msg.sender) + (_uri.length - i) < PremiumUsersMapping[msg.sender].mintingLimit,"Global limit exceed");
            require(phaseMapping[currentPhase].premiumUserLimit >= phaseMapping[currentPhase].premiumUserBalance[msg.sender] + (_uri.length - i), "Phase user limit exceed");
            phaseMapping[currentPhase].premiumUserBalance[msg.sender]++;

        } else {
            require(balanceOf(msg.sender) + (_uri.length - i) < NormalUsersMapping[msg.sender].mintingLimit,"Global limit exceed");
            require(phaseMapping[currentPhase].NormalUserLimit >=  phaseMapping[currentPhase].normalUserBalance[msg.sender] + (_uri.length - i), "Phase user limit exceed");
            phaseMapping[currentPhase].normalUserBalance[msg.sender]++;
        }

        UserMintingLimit--;
        phaseMapping[currentPhase].reservedLimit--;

        _safeMint(to[i], _tokenId[i]);
        _setTokenURI(_tokenId[i], _uri[i]);
        }
    }


    /*
        @dev adminPlatformMinting is used to Mint NFTs.
        Requirement:
        This function can be called by Admins
        @param to,
        @param uri,
        @param tokenId
    */
    function adminPlatformMinting(address to, string memory uri, uint tokenId) public {
        require(adminMapping[msg.sender], "You are not the admin");
        require(platformMintingLimit > 0, "Limit exceed");
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        platformMintingLimit--;
    }

    /*
        @dev adminBulkMinting is used to Mint in bulk size.
        Requirement:
        This function can be called by admins
        @param uri,
        @param tokenId
    */
    function adminBulkMinting(string[] memory uri, uint[] memory tokenId) public {
        require(uri.length == tokenId.length, "Input values correctly" );
        require(adminMapping[msg.sender], "Only admins allowed");
        require(platformMintingLimit > 0 , "Minting limit exceed");

        for(uint i = 0; i < uri.length; i++){
            _safeMint(msg.sender, tokenId[i]);
            _setTokenURI(tokenId[i], uri[i]);
        }

        platformMintingLimit--;
    }

    



    /*
        @dev _transfer is used to Transfer tokens.
        Requirement:
        This function can be called by Registered or verified Users.
        @param from,
        @param to,
        @param tokenId

     
        Emits Transfer(from, to, tokenId);
    */
    function _transfer(address from, address to, uint tokenId) internal override(ERC721){
        require(isTransferable, "Transfer Deactived");

        super._transfer(from, to, tokenId);

        emit Transfer(from, to, tokenId);
    }


    /*
        @dev allowTransfer is used to allow users to transfer the tokens.
        Requirement:
        This function can be called by onlyOwner
    */
    function allowTransfer() public onlyOwner{
        require(!isTransferable, "Already Allowed");
        
        isTransferable = true;
    }

    /*
        @dev updateHashes is used to update the Hashes of NTFs.
        Requirement:
        This function can be called by onlyOwner
        @param hashData
     
        Emits HashUpdated(hashData);
    */
    function updateHashes(bulkNfts[] memory hashData) public onlyOwner {
        for(uint i = 0; i<hashData.length; i++){
            if(ownerOf(hashData[i].tokenId) == msg.sender){
                _setTokenURI(hashData[i].tokenId, hashData[i].uri);
            }
        }

        emit HashUpdated(hashData);
    }

    /*
        @dev updatePhaseReservedLimit is used to update the Phase Reserved Limit.
        Requirement:
        This function can be called by onlyOwner
        @param newLimit

     
        Emits PhaseLimitUpdated(newLimit);
    */
    function updatePhaseReservedLimit(uint newLimit) public onlyOwner{
        require(phaseMapping[currentPhase].isActivate, "Phase is not active");
        require(newLimit > phaseMapping[currentPhase].reservedLimit, "Please enter greater then existing limit");

        phaseMapping[currentPhase].reservedLimit = newLimit;

        emit PhaseLimitUpdated(newLimit);
    }

    /*
        @dev fetchNFTs is used to fetch NFTs.
        Requirement:
        This function can be called by Registered or verified Users.
        @param _address
    */
    function fetchNFTs(address _address) public view returns(bulkNfts[] memory){
        require(balanceOf(_address) > 0, "Invalid balance");

        bulkNfts[] memory nftsArray = new bulkNfts[](balanceOf(_address));

        for(uint i = 0; i < balanceOf(_address); i++){

            uint id = tokenOfOwnerByIndex(_address, i);
            string memory uri  = tokenURI(id);
            nftsArray[i] = bulkNfts(id, uri);

        }
        
        return nftsArray;
    }




    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // function safeMint(address to, uint256 tokenId, string memory uri)
    //     public
    //     onlyOwner
    // {
    //     _safeMint(to, tokenId);
    //     _setTokenURI(tokenId, uri);
    // }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}