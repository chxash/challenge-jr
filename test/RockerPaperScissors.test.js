const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RockPaperScissors", function () {

  before(async function () {
    this.signers = await ethers.getSigners();
    this.alice = this.signers[0];
    this.bob = this.signers[1];
    this.provider = ethers.provider;
  });

  beforeEach(async function () {
    this.RockPaperScissorsFactory = await ethers.getContractFactory("RockPaperScissors");
    this.contract = await this.RockPaperScissorsFactory.deploy();
    await this.contract.deployed();
    await this.contract.connect(this.alice);
  });

  describe("Public methods tests", function () {
    describe("receive() and withdraw() methods", function () {
      it("Should increments user balance when receiving funds", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 100 });
        await this.bob.sendTransaction({ to: this.contract.address, value: 102 });
        expect(await this.contract.balances(this.alice.address)).to.equal(100);
        expect(await this.contract.balances(this.bob.address)).to.equal(102);
      });

      it("Should withdraw requested users fund when calling withdraw() with less than user balance", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 100 });
        await this.bob.sendTransaction({ to: this.contract.address, value: 102 });
        await expect(() => this.contract.withdraw(99)).to.changeEtherBalances([this.alice, this.contract], [99, -99]);
        expect(await this.contract.balances(this.alice.address)).to.equal(1);
        expect(await this.contract.balances(this.bob.address)).to.equal(102);
      });

      it("Should not withdraw requested users fund when calling withdraw() with more than user balance", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 1 });
        await expect(this.contract.withdraw(2)).to.be.revertedWith('Insufficient funds');
        expect(await this.contract.balances(this.alice.address)).to.equal(1);
      });

      it("Should not be possible to withdraw if player is enrolled", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 100 });
        await this.contract.startGame();

        await expect(this.contract.withdraw(2)).to.be.revertedWith('Withdrawing funds is not permitted while playing');
      });

      it("Should not be possible to withdraw if player has submitted a move", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 100 });
        await this.bob.sendTransaction({ to: this.contract.address, value: 102 });

        await this.contract.startGame();
        await this.contract.connect(this.bob).startGame();
        await this.contract.submitMove("ROCK");

        await expect(this.contract.withdraw(2)).to.be.revertedWith('Withdrawing funds is not permitted while playing');
      });
    });

    describe("startGame() method", function () {
      it("Should not enroll player if balance is less than required deposit", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 99 });
        await expect(this.contract.startGame()).to.be.revertedWith('Minimum balance is required');
      });

      it("Should enroll player if balance is more than required deposit and no opponent is available", async function () {
        await this.bob.sendTransaction({ to: this.contract.address, value: 100 });
        await expect(this.contract.connect(this.bob).startGame()).to.emit(this.contract, 'PlayerEnrolled').withArgs(this.bob.address);
      });

      it("Should not enroll player which is already enrolled", async function () {
        await this.bob.sendTransaction({ to: this.contract.address, value: 101 });
        await expect(this.contract.connect(this.bob).startGame());
        await expect(this.contract.connect(this.bob).startGame()).to.be.revertedWith('Player is already enrolled');
      });
    });

    describe("cancelGame() method", function () {
      it("Should be possible to cancel a game if player is enrolled", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 102 });
        await this.contract.startGame();

        await expect(this.contract.cancelGame()).to.not.be.reverted;
      });

      it("Should not be possible to cancel a game if player is enrolled but an opponent has been matched", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 102 });
        await this.bob.sendTransaction({ to: this.contract.address, value: 101 });
        await this.contract.startGame();
        await this.contract.connect(this.bob).startGame();

        await expect(this.contract.cancelGame()).to.be.revertedWith('Only started games without opponents can be cancelled');
      });
    });


    describe("submitMove() method", function () {
      it("Should not proceed if balance is less than required deposit", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 99 });
        await expect(this.contract.submitMove(this.contract.MoveRock)).to.be.revertedWith('Minimum balance is required');
      });

      it("Should not proceed if game was not started by user", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 101 });
        await expect(this.contract.submitMove(this.contract.MoveRock)).to.be.revertedWith('Player is not enrolled yet');
      });

      it("Should not proceed if no opponent has been matched", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 101 });
        await this.contract.startGame();
        await expect(this.contract.submitMove(this.contract.MoveRock)).to.be.revertedWith('No opponent is enrolled yet');
      });

      it("Should not proceed if move is not recognized", async function () {
        await this.alice.sendTransaction({ to: this.contract.address, value: 101 });
        await this.bob.sendTransaction({ to: this.contract.address, value: 100 });
        await this.contract.startGame();
        await this.contract.connect(this.bob).startGame();
        await expect(this.contract.submitMove("")).to.be.revertedWith('Submitted move is invalid');
      });

      it("Should store move and change state if opponent did not submit its move yet", async function () {

      });

      describe("Game resolution cases", function () {
        beforeEach(async function () {
          await this.alice.sendTransaction({ to: this.contract.address, value: 102 });
          await this.bob.sendTransaction({ to: this.contract.address, value: 103 });
          await this.contract.startGame();
          await this.contract.connect(this.bob).startGame();
        });

        it("Should resolves the game if opponent already submitted its move, game result is a tie", async function () {
          await this.contract.submitMove("ROCK");
          await this.contract.connect(this.bob).submitMove("ROCK");
          expect(await this.contract.balances(this.alice.address)).to.equal(102);
          expect(await this.contract.balances(this.bob.address)).to.equal(103);
        });

        it("Should resolves the game if opponent already submitted its move, P1 ROCK > P2 SCISSORS", async function () {
          await this.contract.submitMove("ROCK");
          await this.contract.connect(this.bob).submitMove("SCISSORS");
          expect(await this.contract.balances(this.alice.address)).to.equal(202);
          expect(await this.contract.balances(this.bob.address)).to.equal(3);
        });

        it("Should resolves the game if opponent already submitted its move, P1 ROCK < P2 PAPER", async function () {
          await this.contract.submitMove("ROCK");
          await this.contract.connect(this.bob).submitMove("PAPER");
          expect(await this.contract.balances(this.alice.address)).to.equal(2);
          expect(await this.contract.balances(this.bob.address)).to.equal(203);
        });

        it("Should resolves the game if opponent already submitted its move, P1 PAPER > P2 ROCK", async function () {
          await this.contract.submitMove("PAPER");
          await this.contract.connect(this.bob).submitMove("ROCK");
          expect(await this.contract.balances(this.alice.address)).to.equal(202);
          expect(await this.contract.balances(this.bob.address)).to.equal(3);
        });

        it("Should resolves the game if opponent already submitted its move, P1 PAPER < P2 SCISSORS", async function () {
          await this.contract.submitMove("PAPER");
          await this.contract.connect(this.bob).submitMove("SCISSORS");
          expect(await this.contract.balances(this.alice.address)).to.equal(2);
          expect(await this.contract.balances(this.bob.address)).to.equal(203);
        });

        it("Should resolves the game if opponent already submitted its move, P1 SCISSORS > P2 PAPER", async function () {
          await this.contract.submitMove("SCISSORS");
          await this.contract.connect(this.bob).submitMove("PAPER");
          expect(await this.contract.balances(this.alice.address)).to.equal(202);
          expect(await this.contract.balances(this.bob.address)).to.equal(3);
        });

        it("Should resolves the game if opponent already submitted its move, P1 SCISSORS < P2 ROCK", async function () {
          await this.contract.submitMove("SCISSORS");
          await this.contract.connect(this.bob).submitMove("ROCK");
          expect(await this.contract.balances(this.alice.address)).to.equal(2);
          expect(await this.contract.balances(this.bob.address)).to.equal(203);
        });

        it("should be possible to start a game again after winning", async function () {
          await this.contract.submitMove("ROCK");
          await this.contract.connect(this.bob).submitMove("SCISSORS");
          expect(await this.contract.balances(this.alice.address)).to.equal(202);
          expect(await this.contract.balances(this.bob.address)).to.equal(3);
          await expect(this.contract.startGame()).to.not.be.reverted;
          await expect(this.contract.connect(this.bob).startGame()).to.be.revertedWith('Minimum balance is required');
        });

        it("should not be possible to punish an uncooperative player before a 1 day delay", async function () {
          await this.contract.submitMove("ROCK");
          await this.contract.punish();
          expect(await this.contract.balances(this.alice.address)).to.equal(102);
          expect(await this.contract.balances(this.bob.address)).to.equal(103);

          await network.provider.send("evm_increaseTime", [86399]);

          await this.contract.punish();
          
          expect(await this.contract.balances(this.alice.address)).to.equal(102);
          expect(await this.contract.balances(this.bob.address)).to.equal(103);
        });

        it("should be possible to punish an uncooperative player after a 1 day delay", async function () {
          await this.contract.submitMove("ROCK");
          await this.contract.punish();
          expect(await this.contract.balances(this.alice.address)).to.equal(102);
          expect(await this.contract.balances(this.bob.address)).to.equal(103);
          await network.provider.send("evm_increaseTime", [86400]);

          await this.contract.punish();
          
          expect(await this.contract.balances(this.alice.address)).to.equal(202);
          expect(await this.contract.balances(this.bob.address)).to.equal(3);
        });
      });
    });
  });
});
