import { ContractSystem } from "@tact-lang/emulator";
import { buildOnchainMetadata } from "../../utils/jetton-helpers";
import { Blockchain, SandboxContract, TreasuryContract } from "@ton-community/sandbox";
import { beginCell, contractAddress, fromNano, StateInit, toNano } from "ton-core";
import "@ton-community/test-utils";

import { KittyJetton, InternalMint, TokenTransfer } from "../output/LuckyKitty_KittyJetton";
import { KittyWallet, TokenBurn } from "../output/LuckyKitty_KittyWallet";
import { BuyTickets, LuckyKitty } from "../output/LuckyKitty_LuckyKitty"

//
// This version of test is based on "@ton-community/sandbox" package
//
describe("contract", () => {
    let blockchain: Blockchain;
    let luckyKitty: SandboxContract<LuckyKitty>;
    let token: SandboxContract<KittyJetton>;
    let jettonWallet: SandboxContract<KittyWallet>;
    let deployer: SandboxContract<TreasuryContract>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        deployer = await blockchain.treasury("deployer");

        luckyKitty = blockchain.openContract(await LuckyKitty.fromInit(deployer.address));
        token = blockchain.openContract(await KittyJetton.fromInit(deployer.address));

        const mint: BuyTickets = {
            $$type: "BuyTickets",
            game: "lucky-kitty-lottery"
        };
        
        // Test minting
        await luckyKitty.send(deployer.getSender(), { value: toNano("10") }, mint);

        const deployerWallet = await token.getGetWalletAddress(deployer.address);
        jettonWallet = blockchain.openContract(KittyWallet.fromAddress(deployerWallet));
        const walletData = await jettonWallet.getGetWalletData();
        expect(walletData.owner).toEqualAddress(deployer.address);
        // Check kitty balance
        expect(walletData.balance).toEqual(toNano("1"));
    });

    it("should deploy", async () => {
        // the check is done inside beforeEach, blockchain and token are ready to use
        // console.log((await token.getGetJettonData()).owner);
        // console.log((await token.getGetJettonData()).totalSupply);
        // console.log((await token.getGetJettonData()).max_supply);
        // console.log((await token.getGetJettonData()).content);
    });

    it("should mint successfully", async () => {
        const player = await blockchain.treasury("player");
        const totalSupplyBefore = (await token.getGetJettonData()).total_supply;
        const mintAmount = toNano("0.1");
        const mint: BuyTickets = {
            $$type: "BuyTickets",
            game: "lucky-kitty-lottery"
        };
        
        await luckyKitty.send(player.getSender(), { value: toNano("1") }, mint);

        const totalSupplyAfter = (await token.getGetJettonData()).total_supply;
        expect(totalSupplyBefore + mintAmount).toEqual(totalSupplyAfter);

        const playerWallet = await token.getGetWalletAddress(player.address);
        jettonWallet = blockchain.openContract(KittyWallet.fromAddress(playerWallet));
        const walletData = await jettonWallet.getGetWalletData();
        expect(walletData.owner).toEqualAddress(player.address);
        expect(walletData.balance).toEqual(toNano("0.1"));
    });

    it("should transfer successfully", async () => {
        const sender = await blockchain.treasury("sender");
        const receiver = await blockchain.treasury("receiver");
        const initMintAmount = toNano("10");
        const transferAmount = toNano("1");

        const mintMessage: BuyTickets = {
            $$type: "BuyTickets",
            game: "lucky-kitty-lottery"
        };
        await luckyKitty.send(sender.getSender(), { value: initMintAmount }, mintMessage);

        const senderWalletAddress = await token.getGetWalletAddress(sender.address);
        const senderWallet = blockchain.openContract(KittyWallet.fromAddress(senderWalletAddress));

        // Transfer tokens from sender's wallet to receiver's wallet
        const transferMessage: TokenTransfer = {
            $$type: "TokenTransfer",
            query_id: 1n,
            amount: transferAmount,
            destination: receiver.address,
            response_destination: sender.address,
            custom_payload: null,
            forward_ton_amount: 1n,
            forward_payload: beginCell().endCell(),
        };
        const transferResult = await senderWallet.send(sender.getSender(), { value: transferAmount }, transferMessage);
        // console.log(transferResult.transactions);

        const receiverWalletAddress = await token.getGetWalletAddress(receiver.address);
        const receiverWallet = blockchain.openContract(KittyWallet.fromAddress(receiverWalletAddress));

        const senderWalletDataAfterTransfer = await senderWallet.getGetWalletData();
        const receiverWalletDataAfterTransfer = await receiverWallet.getGetWalletData();

        expect(senderWalletDataAfterTransfer.balance).toEqual(0n); // check that the sender transferred the right amount of tokens
        expect(receiverWalletDataAfterTransfer.balance).toEqual(transferAmount); // check that the receiver received the right amount of tokens
        // const balance1 = (await receiverWallet.getGetWalletData()).balance;
        // console.log(fromNano(balance1));
    });

    it("Mint tokens then Burn tokens", async () => {
        // const sender = await blockchain.treasury("sender");
        const deployerWalletAddress = await token.getGetWalletAddress(deployer.address);
        const deployerWallet = blockchain.openContract(KittyWallet.fromAddress(deployerWalletAddress));
        let deployerBalanceInit = (await deployerWallet.getGetWalletData()).balance;
        console.log("deployerBalanceInit = ", deployerBalanceInit);
        const initMintAmount = toNano("1");

        const mintMessage: BuyTickets = {
            $$type: "BuyTickets",
            game: "lucky-kitty-lottery"
        };

        await luckyKitty.send(deployer.getSender(), { value: toNano("10") }, mintMessage);
        let deployerBalance = (await deployerWallet.getGetWalletData()).balance;
        expect(deployerBalance).toEqual(deployerBalanceInit + initMintAmount);

        let burnAmount = toNano("1");
        const burnMessage: TokenBurn = {
            $$type: "TokenBurn",
            query_id: 0n,
            amount: burnAmount,
            response_destination: deployer.address,
            custom_payload: beginCell().endCell(),
        };

        const burnResult = await deployerWallet.send(deployer.getSender(), { value: toNano("10") }, burnMessage);
        let deployerBalanceAfterBurn = (await deployerWallet.getGetWalletData()).balance;
        expect(deployerBalanceAfterBurn).toEqual(deployerBalance - burnAmount);
    });
});
