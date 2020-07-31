
import "./Owner.sol";
pragma solidity 0.5.12;
import "./ProvableAPI.sol";


contract betDapp is Owner, usingProvable{


    uint betCounter=0;
    uint public balance;
    uint private committedBalance;
    struct outstandingBet{ //Every time a user flips, it will be recorded in this struct with their ETH address and the balance outstanding.
        address payable userAddress;
        uint betAmount;
    }

    uint256 constant NUM_RANDOM_BYTES_REQUESTED = 1;
    uint256 GAS_FOR_CALLBACK=200000;

    mapping (bytes32 => outstandingBet) private results;
    mapping(address => bool) public  waiting;
    mapping(address=>uint) private userBalance;

    event betResult(bytes32 queryID, string res, uint newBalance);
    event load(string loadAmount, uint newBalance);
    event betConfirmation(string conf, bytes32 ID, uint newBalance);
    event logNewProvableQuery(string description);
    event generatedRandomNumber(uint256 randomNumber);
    event gamblerAddres(address whoCalled);
    event userWithdrawal(string message);
    //event balanceCommitted(uint256 committedToBets);

    modifier topUp(uint minTopUp){
        require(msg.value>=minTopUp);
        _;
    }

    constructor() payable public {
        balance+=msg.value;
        checkBalance();
        emit load("Contract Loaded", balance);
    }

    function __callback(bytes32 _queryId,string memory _result, bytes memory _proof) public{
    require(msg.sender==provable_cbAddress()); //only the oracle can call this function

    uint256 randomNumber = uint256(keccak256(abi.encodePacked(_result))) %2;

    //randomNumber=now%2;

    address payable user;
    uint amountToPay;
    string memory result;

    user=results[_queryId].userAddress;
    amountToPay=results[_queryId].betAmount;

        if(randomNumber==1){
            updateBalance(user,true,amountToPay);

            result="You win!";
        }
        else{
            updateBalance(user,false,amountToPay);
            result="You lost, try again!";
        }

    waiting[user]=false;
    emit generatedRandomNumber(randomNumber);
    emit gamblerAddres(user);
    emit betResult(_queryId,result,userBalance[user]); //This is the event to listen to on Web3 with the queryID, result of the bet, and the new user Balance.

    }

    function updateBalance(address payable user, bool addToUser, uint amount) private{
        if(addToUser==true){
            userBalance[user]+=amount*2; //If the user wins the bet, their account gets credited with the bet amount times two, so they double their money. No further action required as the funds are already in CommittedBalance
        }
        else{
        committedBalance-=amount*2; //If the user loses the bet, the funds are taking out of CommittedBalance and into Balance.
        balance+=amount*2;
        }
        require(committedBalance>=userBalance[user], "Error: User balance is higher than total available for payouts");
        checkBalance();

    }


    function random() payable public returns(bytes32){
        uint256 QUERY_EXECUTION_DELAY=0;

        bytes32 betID=provable_newRandomDSQuery( //This returns an id, apparently. Confirmed, all calls to this library return a query ID.
            QUERY_EXECUTION_DELAY,
            NUM_RANDOM_BYTES_REQUESTED,
            GAS_FOR_CALLBACK
            );
        if(betCounter>1){
        balance-=GAS_FOR_CALLBACK;
        }

        require(address(this).balance+msg.value>=committedBalance,"Error: There's more balance committed for payouts than is available on contract");
        balance=address(this).balance-committedBalance; //This will deduct the cost of placing the call to the oracle from the balance

        emit logNewProvableQuery("Bet placed, awaiting result");
        return betID;

    }

    function testRandom(address payable whoCalled, uint256 whatAmount) payable public returns(bytes32){
        bytes32 _queryId=bytes32(keccak256(abi.encodePacked(msg.sender)));

        outstandingBet memory testBet;

        testBet.userAddress=whoCalled;
        testBet.betAmount=whatAmount;


        if(betCounter>1){
            balance-=GAS_FOR_CALLBACK;
            whoCalled.transfer(GAS_FOR_CALLBACK);
        }

        require(address(this).balance>=committedBalance,"Error: There's more balance committed for payouts than is available on contract");
        balance=address(this).balance-committedBalance; //This will deduct the cost of placing the call to the oracle from the balance

        results[_queryId]=testBet;
        __callback(_queryId,"1",bytes("test"));
        return _queryId;
    }

    function getBalance() view public returns (uint){
        return balance;
    }

    function getCommitted() view public returns (uint){
        uint256 toBets;
        toBets=address(this).balance-balance;
        return toBets;
    }

    function getUserBalance() view public returns (uint){
        return userBalance[msg.sender];
    }

      function withdrawUserBalance() public{
        uint toWithdraw=userBalance[msg.sender];

        userBalance[msg.sender]=0;
        committedBalance-=toWithdraw;
        msg.sender.transfer(toWithdraw);

        checkBalance();
        require(userBalance[msg.sender]==0,"Error: User balance has not been reset");

        emit userWithdrawal("Balance successfully withdrawn");

    }

    function flip() payable public{
        require(waiting[msg.sender]==false, "You cannot place a bet when waiting for a result!");
        require(msg.value>=0.001 ether, "You need to send at least 0.001 Ether");
        require(balance>=msg.value, "The contract balance isn't high enough to place this bet");

        uint realBet;

        betCounter+=1;

        if(betCounter>1){ //The first bet is free, the others cost gas which we take out of the better.
        realBet=msg.value-GAS_FOR_CALLBACK;
        committedBalance+=realBet; //And it is also added to the balance of the contract as committed. The cost is deduced and added to the contract balance.
        balance+=GAS_FOR_CALLBACK;
        }
        else{
        realBet=msg.value;
        committedBalance+=realBet;
        }

        balance-=realBet;
        committedBalance+=realBet; //When placing a bet, the potential profit will be reserved in CommittedBalance. This makes sure the 'balance' will always reflect the amount available for additional bets.

        checkBalance();

        waiting[msg.sender]=true;

        outstandingBet memory newBet;

        newBet.userAddress=msg.sender;
        newBet.betAmount=realBet;

        bytes32 betID=random();
        //bytes32 betID=testRandom(newBet.userAddress,newBet.betAmount);

        results[betID]=newBet;
        emit betConfirmation("Bet placed, awaiting result", betID, balance);


    }

    function checkBalance() private view{
        require(committedBalance+balance==address(this).balance, "Error: Contract balance doesn't match balance on the blockchain");
    }

    function loadContract() payable public isOwner topUp(0.001 ether){
        balance+=msg.value;
        checkBalance();
        emit load("Contract Loaded", balance);
    }

}
