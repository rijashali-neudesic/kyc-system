//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

struct Customer {
  // username is provided by the customer, and it is used to track their details
  bytes32 username;
  // customer's data or identity documents provided by the customer
  bytes32 data;
  // status of the KYC request
  bool kycStatus;
  // number of downvotes received from other banks over the customer data
  uint256 downVotes;
  // he number of upvotes received from other banks over the customer data
  uint256 upVotes;
  // unique address of the bank that validated the customer account
  address bank;
}

struct Bank {
  // name of the bank/organization
  bytes32 name;
  // unique Ethereum address of the bank/organization
  address ethAddress;
  // number of complaints against this bank done by other banks
  uint256 complaintReported;
  // number of KYC requests initiated by the bank/organization
  uint256 kycCount;
  // hold the status of the bank - to upVote/downVote
  bool isAllowedToVote;
  // registration number for the bank
  bytes32 regNumber;
}

struct KycRequest {
  // username of Customer
  bytes32 username;
  // address of bank
  address bankAddress;
  // customer's data or identity documents
  bytes32 customerData;
}

contract KycSystem {
  mapping(address => Bank) banks;
  mapping(bytes32 => Customer) customers;
  mapping(bytes32 => KycRequest) kycRequests;

  // Prop to assess if bank has already voted
  mapping(bytes32 => mapping(address => bool)) banksVotedForCustomer;

  uint256 private _totalBanks;
  address[] private _bankAddresses;

  address private immutable _admin;

  constructor() {
    _admin = msg.sender;
    _totalBanks = 0;
  }

  function isKycExistingForCustomer(bytes32 _cUsername) private view returns (bool) {
    return kycRequests[_cUsername].username != 0;
  }

  function refreshVotesForCustomer(bytes32 _cUsername) private {
    mapping(address => bool) storage votedBanks = banksVotedForCustomer[_cUsername];
    for (uint256 i = 0; i < _bankAddresses.length; i++)
      votedBanks[_bankAddresses[i]] = false;
  }

  modifier isValidBank(address _bankAddr) {
    require(banks[_bankAddr].regNumber != 0, "Invalid bank");
    _;
  }

  modifier isValidBankAndAllowedToVote(address _bankAddr, bytes32 _cUsername) {
    Bank memory bank = banks[_bankAddr];
    require(bank.regNumber != 0, "Invalid bank"); 
    require(bank.isAllowedToVote, "Bank is not allowed to cast vote");
    require(banksVotedForCustomer[_cUsername][_bankAddr] == false, 'Bank has already voted'); 
    _;
  }

  modifier isNewCustomer(bytes32 _name) {
    require(customers[_name].username == 0, "Customer already exits");
    _;
  }

  modifier isValidCustomer(bytes32 _name) {
    require(customers[_name].username != 0, "Invalid customer");
    _;
  }

  modifier isNewKycRequest(bytes32 _cUsername) {
    require(!isKycExistingForCustomer(_cUsername), "KYC already exist");
    _;
  }

  modifier isExisingKyc(bytes32 _cUsername) {
    require(isKycExistingForCustomer(_cUsername), "KYC request doesn't exist");
    _;
  }

  modifier restrictAsAdminFunc() {
    require(msg.sender == _admin, "Operation not authorized");
    _;
  }

  function determineKycStatus(bytes32 _cUsername) private {
    Customer storage customer = customers[_cUsername];
    customer.kycStatus = 
      _totalBanks > 10 && (100 * customer.downVotes) / _totalBanks > 33
      ? false
      : customer.upVotes > customer.downVotes;
  }

  function determineBankVotingStatus(address _bankAddr) private {
    Bank storage bank = banks[_bankAddr];
    bank.isAllowedToVote = (100 * bank.complaintReported) / _totalBanks <= 33; 
  }
  
  //Check for valid bank + bank can create new KYC request
  function addKycRequest(bytes32 _cUsername, bytes32 _customerData) public isValidBank(msg.sender) isValidCustomer(_cUsername) isNewKycRequest(_cUsername) {
    kycRequests[_cUsername] = KycRequest({
      username: _cUsername,
      customerData: _customerData,
      bankAddress: msg.sender
    });
    ++banks[msg.sender].kycCount;
  } 

  function removeKycRequest(bytes32 _cUsername) public isExisingKyc(_cUsername) isValidBank(msg.sender) {
    delete kycRequests[_cUsername];
    --banks[msg.sender].kycCount;
    assert(kycRequests[_cUsername].username == 0);
  }

  function addCustomer(bytes32 _name, bytes32 _data) public isNewCustomer(_name) isValidBank(msg.sender) {
    customers[_name] = Customer({
      username: _name,
      data: _data,
      kycStatus: false,
      downVotes: 0,
      upVotes: 0,
      bank: msg.sender
    });
  }

  function modifyCustomer(bytes32 _cUsername, bytes32 _data) public isValidBank(msg.sender) isValidCustomer(_cUsername) returns(bool success) {
    Customer storage customer = customers[_cUsername]; 
    customer.data = _data;
    customer.downVotes = 0;
    customer.upVotes = 0;
    refreshVotesForCustomer(_cUsername);
    if (isKycExistingForCustomer(_cUsername))
      removeKycRequest(_cUsername);
    return true;
  }

  function viewCustomer(bytes32 _cUsername) public view isValidCustomer(_cUsername) returns(Customer memory customer) {
    return customers[_cUsername];
  }

  // Add check on KYC request 
  function upVoteCustomer(bytes32 _cUsername) public isValidBankAndAllowedToVote(msg.sender, _cUsername) isValidCustomer(_cUsername) isExisingKyc(_cUsername) {
    Customer storage customer = customers[_cUsername];
    require(customer.bank != msg.sender, "Cannot up vote bank's own customer");

    ++customer.upVotes;
    banksVotedForCustomer[_cUsername][msg.sender] = true;
    determineKycStatus(_cUsername);
  } 
  
  // Add check on KYC request 
  function downVoteCustomer(bytes32 _cUsername) public isValidBankAndAllowedToVote(msg.sender, _cUsername) isValidCustomer(_cUsername) isExisingKyc(_cUsername) {
    Customer storage customer = customers[_cUsername];
    require(customer.bank != msg.sender, "Cannot down vote bank's own customer");

    ++customer.downVotes;
    banksVotedForCustomer[_cUsername][msg.sender] = true;
    determineKycStatus(_cUsername);
  } 

  function getBankComplaints(address _bankAddr) public view isValidBank(_bankAddr) returns (uint256) {
    return banks[_bankAddr].complaintReported; 
  }

  function viewBankDetails(address _bankAddr) public view isValidBank(_bankAddr) returns (Bank memory bank) {
    return banks[_bankAddr]; 
  }

  function reportBank(address _bankAddr) public isValidBank(_bankAddr) {
    ++banks[_bankAddr].complaintReported;
    
    determineBankVotingStatus(_bankAddr);
  }

  function addBank(bytes32 _name, address _ethAddress, bytes32 _regNumber) public restrictAsAdminFunc {
    require(banks[_ethAddress].regNumber == 0, "Bank with address already exist");
    
    banks[_ethAddress] = Bank({
      name: _name,
      ethAddress: _ethAddress,
      complaintReported: 0, 
      kycCount: 0,
      isAllowedToVote: true,
      regNumber: _regNumber
    });
    _bankAddresses.push(_ethAddress); 
    ++_totalBanks;
  } 

  function modifyBankIsAllowedToVote(address _bankAddr, bool _allowed) public restrictAsAdminFunc isValidBank(_bankAddr) {
    banks[_bankAddr].isAllowedToVote = _allowed;
  }
  
  // Check on customer specifics
  function removeBank(address _bankAddr) public restrictAsAdminFunc isValidBank(_bankAddr) {
    delete banks[_bankAddr];
    --_totalBanks;
    assert(banks[_bankAddr].regNumber == 0);
  }
}
