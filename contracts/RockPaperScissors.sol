//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

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
        console.log("Deploying Rock Paper Scissors game");
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(amount <= balances[msg.sender], "Insufficient funds");
        require(playersInfo[msg.sender].state != State.MOVE_SUBMITTED && playersInfo[msg.sender].state != State.ENROLLED, "Withdrawing funds is not permitted while playing");
        balances[msg.sender]-=amount;
        payable(msg.sender).transfer(amount);
    }

    function startGame() external {
        require(requiredDeposit <= balances[msg.sender], "Minimum balance is required");
        require(playersInfo[msg.sender].state != State.ENROLLED, "Player is already enrolled");

        playersInfo[msg.sender].state = State.ENROLLED;

        if (latestAvailableOpponentAddress != address(0)) {
            playersInfo[msg.sender].opponent = latestAvailableOpponentAddress;
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
        require(playersInfo[msg.sender].state == State.ENROLLED && playersInfo[msg.sender].opponent == address(0), "Only started games without opponents can be cancelled");
        resetPlayersInfo();
    }

    // Hash move pour cacher ?
    // Gas cost
    function submitMove(string memory move) public {
        // checking if player already paid required tokens
        require(requiredDeposit <= balances[msg.sender], "Minimum balance is required");
        require(playersInfo[msg.sender].state == State.ENROLLED, "Player is not enrolled yet");

        //checking if 2 players are enrolled
        require(playersInfo[msg.sender].opponent != address(0), "No opponent is enrolled yet");

        // discard invalid moves
        require(compareStrings(move, MoveRock) || compareStrings(move, MovePaper) || compareStrings(move, MoveScissors), "Submitted move is invalid");

        playersInfo[msg.sender].state = State.MOVE_SUBMITTED;

        playersInfo[msg.sender].move = move;

        // storage or memory ?
        PlayerInfo storage opponent = playersInfo[playersInfo[msg.sender].opponent];
        //checking if opponent already played => resolution
        if (opponent.state == State.MOVE_SUBMITTED) {
            // Equality
            if (compareStrings(playersInfo[msg.sender].move, opponent.move)) {
                resolveTie();
            }
            else if (compareStrings(playersInfo[msg.sender].move, MoveRock)) {
                // ROCK > SCISSORS
                if (compareStrings(opponent.move, MoveScissors)) {
                    resolveWin();
                }

                // ROCK < PAPER
                if (compareStrings(opponent.move, MovePaper)) {
                    resolveLose();
                }
            }
            else if (compareStrings(playersInfo[msg.sender].move, MovePaper)) {
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
        console.log("Hero won");
        balances[playersInfo[msg.sender].opponent]-=requiredDeposit;
        balances[msg.sender]+=requiredDeposit;
        resetPlayersInfo();
    }

    function resolveLose() internal {
        console.log("Hero lost");
        balances[playersInfo[msg.sender].opponent]+=requiredDeposit;
        balances[msg.sender]-=requiredDeposit;
        resetPlayersInfo();
    }

    function resolveTie() internal {
        console.log("it's a tie");
        resetPlayersInfo();
    }

    function resetPlayersInfo() internal {
        playersInfo[msg.sender].state = State.IDLE;
        playersInfo[msg.sender].opponent = address(0);
        playersInfo[msg.sender].move = "";
        playersInfo[msg.sender].timeout = 0;
        playersInfo[playersInfo[msg.sender].opponent].state = State.IDLE;
        playersInfo[playersInfo[msg.sender].opponent].opponent = address(0);
        playersInfo[playersInfo[msg.sender].opponent].move = "";
        playersInfo[playersInfo[msg.sender].opponent].timeout = 0;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        bool result = (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
        return result;
    }
}
