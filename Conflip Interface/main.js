var web3 = new Web3(Web3.givenProvider);

$(document).ready(function() {
    window.ethereum.enable().then(function(accounts){ // window.ethereum.enable brings up the Metamask prompt in the webpage.
      contractInstance=new web3.eth.Contract(abi, "0x6367eff37752E33288D9320f294f7FCD23268Db1", {from: accounts[0]}); //This creates an instance of a contract, the argument abi is the functions and variables therein (see abi.js), the second argument is the contract address, as a string. Finally, the third specifies the sender for the contract.
      console.log(contractInstance);
      fetchAndDisplay();
      updatePlayerBalance();
      var betID

      var eventBetPlaced= contractInstance.events.
      betConfirmation(function(err, result){
        if (err){
          console.log(err);
        }
        else {
          console.log(result);
          betID=result.returnValues[1];
          console.log(betID);
        }
      })

      var eventBetResolved=contractInstance.events.
      betResult({filter: {queryID: betID}
      }, function(err, result){
        if (err){
          console.log(err);
        }
        else{
          console.log(result);
          var message=result.returnValues[1];
          $("#result_output").text(message);
          fetchAndDisplay();
          updatePlayerBalance();
        }
      })

    });

    $("#withdraw_user_button").click(withdrawBalance);
    $("#place_bet_button").click(placeBet);
    $("#top_up_button").click(topUp);

});

function fetchAndDisplay(){
  contractInstance.methods.getBalance().call().then(function(res){
    console.log(res);
    $("#balance_output").text(web3.utils.fromWei(res,"ether") + " Ether");
  });
}

function placeBet(){
  var bet=$("#bet_input").val();

  var config = {
    value: web3.utils.toWei(String(bet),"ether")
  }

  contractInstance.methods.flip().send(config)
  .on("receipt", function(receipt){
    console.log("Bet placed, awaiting result.")
    var message=receipt.events.betConfirmation.returnValues[0];
    betID=receipt.events.betConfirmation.returnValues[1]
    var balance=receipt.events.betConfirmation.returnValues[2];
    console.log(receipt);
    console.log(betID);
    $("#result_output").text(message);
    $("#balance_output").text(web3.utils.fromWei(balance,"ether") + " Ether");
    updatePlayerBalance();
  })
  .on('transactionHash', function(hash){
    console.log(hash);
    $("#result_output").text("Bet Placed");
  })

}

function withdrawBalance(){
  contractInstance.methods.withdrawUserBalance().send()
  .on('receipt', function (receipt){
    console.log(receipt);
    $("#user_balance_output").text("0 Ether");
    $("#result_output").text("Balance Withdrawn");
  });
}

function updatePlayerBalance() {
    contractInstance.methods
        .getUserBalance().call()
        .then(function (res) {
            console.log(res);
            $("#user_balance_output").text(web3.utils.fromWei(res,"ether") + " Ether");
        });
}

function topUp(){
  var topUp=$("#top_up_input").val();

  var config = {
    value: web3.utils.toWei(String(topUp),"ether")
  }

contractInstance.methods.loadContract().send(config)
.on('transactionHash', function(hash){
    console.log("Contract loaded");
    $("#result_output").text("Top-up successful");
    fetchAndDisplay()
  })
  .on('receipt', function(receipt){
    var balance=receipt.events.load.returnValues[1];
    $("#balance_output").text(web3.utils.fromWei(balance,"ether") + " Ether");
  })
}
