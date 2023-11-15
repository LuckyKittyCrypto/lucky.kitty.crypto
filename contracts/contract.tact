import "@stdlib/deploy";
import "./jetton";

message Mint {
    amount: Int;
    receiver: Address;
}

contract LuckyKitty with Deployable {  
    receive("Mint: 100") { // Public Minting
        let ctx: Context = context();
        let kittyMinter: Address = initOf KittyJetton(myAddress(), {
            name: "Test Token Name",
            description: "This is description of Test Jetton Token in Tact-lang",
            symbol: "TTN",
            image: "https://avatars.githubusercontent.com/u/104382459?s=200&v=4",
        }.toCell());

        require(self.mintable, "Not mintable");
        require(self.total_supply + 100 <= self.max_supply, "Max supply exceeded");

        self.mint(ctx.sender, 100, self.owner); // 🔴 
    }

    receive("Owner: MintClose") {
        let ctx: Context = context();

        require(ctx.sender == self.owner, "Not owner");

        self.mintable = false;
    }
}

contract KittyJetton with Jetton {
    total_supply: Int as coins;
    owner: Address;
    content: Cell;
    mintable: Bool;

    init(owner: Address, content: Cell, max_supply: Int) {
        self.total_supply = 0;
        self.owner = owner;
        self.mintable = true;
        self.content = content;
    }

    receive(msg: Mint) {
        let ctx: Context = context();

        require(ctx.sender == self.owner, "Not owner");
        require(self.mintable, "Not mintable");

        self.mint(msg.receiver, msg.amount, self.owner); // (to, amount, response_destination)
    }
} 