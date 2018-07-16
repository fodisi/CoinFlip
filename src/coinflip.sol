pragma solidity ^0.4.24;

/** @title Basic contract for betting on the result of a coin flip (head or tail). */
contract CoinFlip {
    /* SECURITY NOTE: For simplicity reasons, this contract uses 
    "block.timestamp" to compare timestamps durations and to generate
    random numbers. This is a known security issue, but the decision to
    use this design was made assuming this contract was written for
    learning purposes only, and it is not going to be published on the
    Ethereum main net.*/

    // Defines the betting options. Head==0; Tail==1.
    enum BetOption {HEAD, TAIL}

    // Event to be raised when a new bet is placed.
    event NewBet(uint betSessionId, address player, uint amount, uint option);
    // Event to be raised when a new Result is announced for a bet session.
    event NewResult(uint betSessionId, uint totalBetsCount, uint headBetsCount, uint tailBetsCount, BetOption betSessionResult);
    
    // Represents a single bet.
    struct Bet {
        address player;
        uint amount;
        BetOption option;
    }
    
    // The result of a bet.
    // BetOption public betResult; // 0 == tails; 1 == heads
    // Determines the minimum value accepted for a bet (in wei - simplicity).
    uint public minBet;
    // The contract's instance owner.
    address private owner;
    uint private ownerFee;
    // A key/value list of player and its bet.
    Bet[] private bets;
    // Stores the addresses of players who placed bets on HEADS.
    //address[] private headPlayers;
    // Stores the addresses of players who placed bets on TAILS.
    //address[] private tailPlayers;
    // Unique identifier for a bet session.
    uint private betSessionId = 0;
    // Determines the date/time a bet was open.
    uint private betOpenTimestamp;
    // Determines the duration a of bet.
    uint private betDuration;
    // Counts the total number of bets placed by players.
    uint private totalBetsCount;
    // Counts the number of HEAD bets placed by players.
    uint private headBetsCount;
    // Counts the number of TAIL bets placed by players.
    uint private tailBetsCount;
    // $ amount placed on HEAD bets.
    uint private headBetsAmount;
    // $ amount placed on TAIL bets.
    uint private tailBetsAmount;
    
    modifier onlyOwner() {
        require (msg.sender == owner);
        _;
    }

    modifier notOwner() {
        require (msg.sender != owner);
        _;
    }

    modifier betIsOpen() {
        require(block.timestamp <= betOpenTimestamp + betDuration * 1 minutes);
        _;
    }

    modifier betIsClosed() {
        require(block.timestamp > betOpenTimestamp + betDuration * 1 minutes);
        _;
    }    
    
    constructor() public {
        owner = msg.sender;
    }
    
    function openBetSession(uint minAmount, uint duration, uint fee) external onlyOwner {
        require(duration > 0);
        require(minAmount > 0);

        // Sets a new unique identifier for the bet session.
        betSessionId++;
        // Reset list of bets and players.
        delete bets;
        //delete headPlayers;
        //delete tailPlayers;
        // Reset bet counters.
        totalBetsCount = 0;
        headBetsCount = 0;
        tailBetsCount = 0;
        headBetsAmount = 0;
        tailBetsAmount = 0;
        // Sets bet properties.
        minBet = minAmount;
        betDuration = duration;
        ownerFee = fee;
        betOpenTimestamp = block.timestamp;

        // TODO: raise an event when an bet is open.
    }
    
    /** @dev Allows a player to place a bet.
        @param option Bet option chosen by the player. Allowed values are 0 (Heads) and 1 (Tails).
    */
    function placePlayerBet(uint option) external payable notOwner betIsOpen {
        // Checks if player's bet value meets minimum bet requirement.
        require(msg.value >= minBet);
        // Checks if player's option is a valid bet option. Value must be in (0==heads; 1==tails).
        require(option <= uint(BetOption.TAIL));

        // Increments bet counters (total and specific option (head/tail)).
        totalBetsCount++;
        if (option == uint(BetOption.HEAD)) {
            headBetsCount++;
            headBetsAmount += msg.value;
            //headPlayers.push(msg.sender);
        } else {
            tailBetsCount++;
            tailBetsAmount += msg.value;
            //tailPlayers.push(msg.sender);
        }

        // Creates a new Bet and assigns it to the list of bets.
        bets.push(Bet(msg.sender, msg.value, BetOption(option)));

        // Raises an event for the bet placed by the player.
        emit NewBet(betSessionId, msg.sender, msg.value, option);
    }

    function announcesSessionResultAndPay() external onlyOwner betIsClosed {
        BetOption result = flipCoin();
        rewardWinners(result);
        emit NewResult(betSessionId, totalBetsCount, headBetsCount, tailBetsCount, result);
    }
    
    function flipCoin() private view onlyOwner betIsClosed returns (BetOption) {
        return BetOption(uint(keccak256(abi.encodePacked(block.timestamp, betSessionId))) % 2);
    }
    
    function rewardWinners(BetOption result) private onlyOwner betIsClosed {
        BetOption winningOption = BetOption(result);
        // calculates the fee that goes to the house/contract.
        uint fee = address(this).balance * ownerFee / 100;
        uint totalPrize = address(this).balance - fee;
        uint winningBetAmout = 0;

        if (winningOption == BetOption.HEAD) {
            winningBetAmout = headBetsAmount;
        } else {
            winningBetAmout = tailBetsAmount;
        }

        // Pays out players
        for (uint i = 0; i < bets.length; i++) {
            Bet memory curBet = bets[i];
            if (curBet.option == winningOption) {
                // Gets the percentage of the player's bet, em relation to the amount
                // betted on the winning result.
                uint relativeBetSize = curBet.amount / winningBetAmout * 100;
                // Calculates the prize for the player, considering its 
                // stake (relativeBetSize) em relation to the total prize.
                uint prize = totalPrize * relativeBetSize / 100;
                // Pays the player.
                curBet.player.transfer(prize);
            }
            // No prize for losers.
        }

        // Pays owner's fee - gas.
        owner.transfer(address(this).balance);

    }

    // IMPROVEMENT IDEA - Create public function that can be called after a period of time by any
    // player, in case owner did not announce winners within a certain time.
}