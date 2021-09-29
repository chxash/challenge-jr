# Rock-Paper-Scissors test project

Workflow for a user is :
- Deposit to the contract
- Call startGame() method
- Call cancelGame() method is possible until an opponent starts a game
- Call submitMove() method (will proceed only when an opponent starts a game)
- Call punish() when facing an uncooperative opponent (1 day delay before punish is possible)
- Withdraw or play again

TODO for production : 
- Implements commitment scheme in order to conceal moves
