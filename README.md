# CoinFlip

The contract was crated using the specific logic (steps):
    1. The owner/house opens a Betting Session specifying the characteristics
    of the session: minimum bet, duration of the session (in minutes), 
    house fee (%). Concurrent bets are not allowed.
	
    2. Once a session is open, players can place the bets. However the bet must
    be placed within the specified duration / timeframe of the betting session
    (specified when the betting session was opened). After the session duration
    ends, players cannot place bets.
    
	3. The owner/house announces the result of the betting session and pays out
    the winners. The result cannot be announced while the betting session is
    opened. Once the result of the current betting session is announced, the 
    owner/house will be allowed to open a new opened session.