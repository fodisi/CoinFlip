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

    event BetSessionOpened(uint sessionId, uint minimumBet, uint duration, uint openTimestamp);
    // Event to be raised when a new bet is placed.
    event NewBetPlaced(uint betSessionId, address player, uint amount, BetOption option);
    // Event to be raised when a new Result is announced for a bet session.
    event SessionResultAnnounced(
        uint betSessionId,
        uint totalBetsCount, 
        uint headBetsCount,
        uint tailBetsCount,
        BetOption betSessionResult
    );
    
    // Represents a player's bet.
    struct Bet {
        address player;
        uint amount;
        BetOption option;
    }

    // Represents a bet session, where players can place bets following the session constraints.
    struct BetSession {
        uint minimumBet;
        uint ownerFee;
        uint duration;
        uint openTimestamp;
        uint count;
        uint headsCount;
        uint tailsCount;
        uint headsAmount;
        uint tailsAmount;
    }
    
    // The contract's instance owner.
    address private owner;
    // Unique identifier for a bet session.
    uint private sessionIndex;
    //BetSession currentSession;
    BetSession[] private sessions;
    // Maps the bets placed in each session.
    mapping(uint => Bet[]) betsBySession;
    // Indicates if there's an ongoing session.
    bool ongoingSession = false;
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier notOwner() {
        require(msg.sender != owner);
        _;
    }
    modifier openForBets() {
        require(block.timestamp <= sessions[sessionIndex].openTimestamp + (sessions[sessionIndex].duration * 1 minutes));
        _;
    }

    modifier closedForBets() {
        require(block.timestamp > sessions[sessionIndex].openTimestamp + (sessions[sessionIndex].duration * 1 minutes));
        _;
    }    
    
    constructor() public {
        owner = msg.sender;
    }
    
    /** @dev Opens a session for bets.
        @param minAmount the minimum amount to be allowed when placing bets.
        @param duration the time frame duration that the session will be open for bets.
        @param fee the house fee that will be paid to the contract's owner.
    */
    function openBetSession(uint minAmount, uint duration, uint fee) external onlyOwner {
        require(duration > 0);
        require(minAmount > 0);
        require(fee > 0 && fee < 15); // house fee must be between 0 and 15%.
        require(ongoingSession == false);

        // Do not allow concurrent betting sessions.
        ongoingSession = true;
        uint openedAt = block.timestamp;
        // Creates a new betting session using the specified parameters.
        sessions.push(BetSession(minAmount, fee, duration, openedAt, 0, 0, 0, 0, 0));
        // Sets a new unique identifier for the bet session.
        sessionIndex = sessions.length - 1;
        // Raises an event notifying a new betting session was open.
        emit BetSessionOpened(sessionIndex, minAmount, duration, openedAt);
    }
    
    /** @dev Allows a player to place a bet on a specific outcome (head or tail).
        @param option Bet option chosen by the player. Allowed values are 0 (Heads) and 1 (Tails).
    */
    function placeBet(uint option) external payable notOwner openForBets {
    // Used the header bellow to test on REMIX, since it was not allowing to execute the code
    // from other accounts that were not the owner (function "At address").
    //function placeBet(uint option, address player) external payable openForBets {
        // Checks if player's bet value meets minimum bet requirement.
        require(msg.value >= sessions[sessionIndex].minimumBet);
        // Checks if player's option is a valid bet option. Value must be in (0==heads; 1==tails).
        require(option <= uint(BetOption.TAIL));

        // Creates a new Bet and assigns it to the list of bets.
        betsBySession[sessionIndex].push(Bet(msg.sender, msg.value, BetOption(option)));
        // See note at beginning of function.
        //betsBySession[sessionIndex].push(Bet(player, msg.value, BetOption(option)));
        updateSessionStats(BetOption(option), msg.value);

        // Raises an event for the bet placed by the player.
        emit NewBetPlaced(sessionIndex, msg.sender, msg.value, BetOption(option));
    }

    /** @dev Announces the winning result for the betting session and pays out winners. */
    function announcesSessionResultAndPay() external onlyOwner closedForBets {
        BetOption result = flipCoin();
        rewardWinners(result);
        ongoingSession = false;
        emit SessionResultAnnounced(
            sessionIndex,
            sessions[sessionIndex].count,
            sessions[sessionIndex].headsCount,
            sessions[sessionIndex].tailsCount,
            result
        );
    }
    
    /** @dev Updates the stats (counters and amounts) of the current betting session.
        @param option 
    */
    function updateSessionStats(BetOption option, uint betAmount) private openForBets {
        // Increments bet counters (total and specific option (head/tail)).
        sessions[sessionIndex].count++;
        if (option == BetOption.HEAD) {
            sessions[sessionIndex].headsCount++;
            sessions[sessionIndex].headsAmount += betAmount;
        } else {
            sessions[sessionIndex].tailsCount++;
            sessions[sessionIndex].tailsAmount += betAmount;
        }
    }

    function flipCoin() private view onlyOwner closedForBets returns (BetOption) {
        // PS: Known insecure random generation (designed for simplicity).
        return BetOption(uint(keccak256(abi.encodePacked(block.timestamp, sessionIndex))) % 2);
    }
    
    function rewardWinners(BetOption result) private onlyOwner closedForBets {
        BetOption winningOption = BetOption(result);
        // calculates the fee that goes to the house/contract.
        uint fee = address(this).balance * sessions[sessionIndex].ownerFee / 100;
        uint totalPrize = address(this).balance - fee;
        uint winningBetAmount;

        if (winningOption == BetOption.HEAD) {
            winningBetAmount = sessions[sessionIndex].headsAmount;
        } else {
            winningBetAmount = sessions[sessionIndex].tailsAmount;
        }

        // Pays out players
        for (uint i = 0; i < betsBySession[sessionIndex].length; i++) {
            Bet memory curBet = betsBySession[sessionIndex][i];
            if (curBet.option == winningOption) {
                // Gets the percentage of the player's bet, em relation to the amount
                // betted on the winning result.
                uint relativeBetSize = curBet.amount / winningBetAmount * 100;
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