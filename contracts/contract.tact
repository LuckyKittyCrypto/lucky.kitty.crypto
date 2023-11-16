import "@stdlib/deploy";
import "./jetton";
import "./messages";

struct KittyTokenContent {
    name: String;
    description: String;
    symbol: String;
    image: String;
}

contract LuckyKitty with Deployable {
    owner: Address;

    init(owner: Address) {
        self.owner = owner;
    }

    receive(msg: BuyTickets) {
        let ctx: Context = context();
        require(ctx.value > ton("0.15"), "At least 0.15 TON");

        let kittyMinter: StateInit = initOf KittyJetton(self.owner);

        send(SendParameters{
            to: contractAddress(kittyMinter),
            value: ton("0.15"),
            bounce: false,
            body: InternalMint {
                amount: ctx.value / 10,
                receiver: sender()
            }.toCell(),
            data: kittyMinter.data,
            code: kittyMinter.code
        });
    }
}

contract KittyJetton with Jetton {
    total_supply: Int as coins;
    owner: Address;
    content: Cell;
    mintable: Bool;

    init(owner: Address) {
        self.total_supply = 0;
        self.owner = owner;
        self.mintable = true;
        self.content = KittyTokenContent{    
            name: "Kitty Token Name",
            description: "This is the kitty token of Lucky Kitty",
            symbol: "KITTY",
            image: "https://avatars.githubusercontent.com/u/150975418?v=4"
        }.toCell();
    }

    receive(msg: InternalMint) {
        require(sender() != self.owner, "Not allowed to mint");
        self.mint(msg.receiver, msg.amount, self.owner);
    }
} 