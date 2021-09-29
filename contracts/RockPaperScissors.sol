//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// Workflow for a user is :
// 1. Deposit to the contract
// 2. Call startGame() method
// 3. Call submitMove() method
// 4. Call punish() when facing an uncooperative opponent
// 5. Withdraw or play again
contract RockPaperScissors {
    uint public constant requiredDeposit = 100;
    string public constant MoveRock = "ROCK";
    string public constant MovePaper = "PAPER";
    string public constant MoveScissors = "SCISSORS";

    enum State {IDLE, ENROLLED, MOVE_SUBMITTED}

    event PlayerEnrolled(address indexed player);

    struct PlayerInfo {
        State state;
        address opponent;
        string move;
        uint timeout;
    }

    address latestAvailableOpponentAddress;

    /* This creates an array with all balances */
    mapping (address => uint256) public balances;

    /* Array with all players information */
    mapping (address => PlayerInfo) internal playersInfo;

    constructor() {
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(amount <= balances[msg.sender], "Insufficient funds");
        require(playersInfo[msg.sender].state != State.MOVE_SUBMITTED && playersInfo[msg.sender].state != State.ENROLLED, "No withdrawals while playing");
        balances[msg.sender]-=amount;
        payable(msg.sender).transfer(amount);
    }

    function startGame() external {
        require(requiredDeposit <= balances[msg.sender], "Minimum balance is required");

        PlayerInfo storage player = playersInfo[msg.sender];

        require(player.state != State.ENROLLED, "Player is already enrolled");

        player.state = State.ENROLLED;

        if (latestAvailableOpponentAddress != address(0)) {
            player.opponent = latestAvailableOpponentAddress;
            playersInfo[latestAvailableOpponentAddress].opponent = msg.sender;
            latestAvailableOpponentAddress = address(0);
        } else {
            latestAvailableOpponentAddress = msg.sender;
        }

        emit PlayerEnrolled(msg.sender);
    }

    // This method can be called to cancel a game before an opponent has been matched
    // Afterwards, it's not possible anymore to cancel a game
    function cancelGame() external {
        require(playersInfo[msg.sender].state == State.ENROLLED && playersInfo[msg.sender].opponent == address(0), "Current game is not cancellable");
        if (latestAvailableOpponentAddress == msg.sender) {
            latestAvailableOpponentAddress = address(0);
        }

        resetPlayersInfo();
    }

    // In order to have a secure game, we would need to require each user to send a hash of [random value, move] as a first commitment.
    // Then the users would reveal their move in a second step.
    function submitMove(string memory move) public {
        PlayerInfo storage player = playersInfo[msg.sender];

        // checking if player already paid required tokens
        require(requiredDeposit <= balances[msg.sender], "Minimum balance is required");
        require(player.state == State.ENROLLED, "Player is not enrolled yet");

        //checking if 2 players are enrolled
        require(player.opponent != address(0), "No opponent is enrolled yet");

        // discard invalid moves
        require(compareStrings(move, MoveRock) || compareStrings(move, MovePaper) || compareStrings(move, MoveScissors), "Submitted move is invalid");

        player.state = State.MOVE_SUBMITTED;
        player.move = move;

        PlayerInfo storage opponent = playersInfo[player.opponent];
        //checking if opponent already played => resolution
        if (opponent.state == State.MOVE_SUBMITTED) {
            // Equality
            if (compareStrings(player.move, opponent.move)) {
                resolveTie();
            }
            else if (compareStrings(player.move, MoveRock)) {
                // ROCK > SCISSORS
                if (compareStrings(opponent.move, MoveScissors)) {
                    resolveWin();
                }

                // ROCK < PAPER
                if (compareStrings(opponent.move, MovePaper)) {
                    resolveLose();
                }
            }
            else if (compareStrings(player.move, MovePaper)) {
                // PAPER > ROCK
                if (compareStrings(opponent.move, MoveRock)) {
                    resolveWin();
                }

                // PAPER < SCISSORS
                if (compareStrings(opponent.move, MoveScissors)) {
                    resolveLose();
                }
            }
            else {
                // SCISSORS > PAPER
                if (compareStrings(opponent.move, MovePaper)) {
                    resolveWin();
                }

                // SCISSORS < ROCK
                if (compareStrings(opponent.move, MoveRock)) {
                    resolveLose();
                }
            }
        } else {
            // start timer for opponent to play
            opponent.timeout = block.timestamp + 1 days;
        }
    }

    // Method to be called to retrieve opponent's token after timeout is elapsed (1 day timeout)
    function punish() public {
        uint256 timeout = playersInfo[playersInfo[msg.sender].opponent].timeout;
        if (timeout != 0 && block.timestamp > timeout) {
            resolveWin();
        }
    }

    function resolveWin() internal {
        balances[playersInfo[msg.sender].opponent]-=requiredDeposit;
        balances[msg.sender]+=requiredDeposit;
        resetPlayersInfo();
    }

    function resolveLose() internal {
        balances[playersInfo[msg.sender].opponent]+=requiredDeposit;
        balances[msg.sender]-=requiredDeposit;
        resetPlayersInfo();
    }

    function resolveTie() internal {
        resetPlayersInfo();
    }

    function resetPlayersInfo() internal {
        delete playersInfo[playersInfo[msg.sender].opponent];
        delete playersInfo[msg.sender];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        bool result = (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
        return result;
    }
}
