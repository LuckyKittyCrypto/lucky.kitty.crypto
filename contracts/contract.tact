import "@stdlib/deploy";
import "./jetton";
import "./messages";

struct KittyTokenContent {
    name: String;
    description: String;
    symbol: String;
    image: String;
}

message LoanFull {
    lender: Address;
    nextLoan: Address;
}

message SetNextLoan {
    nextLoan: Address;
}

message KittyLoan {
    amount: Int;
}

contract Loan {
    owner: Address;
    lender: Address;
    nextLoan: Address?;

    amount: Int as coins;

    init(owner: Address, lender: Address, amount: Int) {
        require(amount > 0, "Amount must be positive");

        self.owner = owner;
        self.lender = lender;
        self.amount = amount;
    }

    receive(msg: SetNextLoan) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not allowed to set next loan");
        require(self.nextLoan != null, "Next loan already set");
        self.nextLoan = msg.nextLoan;
    }

    receive("init") {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not allowed to init loan");
        require(self.nextLoan == null, "Next loan already set");
        self.nextLoan = ctx.sender;
    }
}

contract LuckyKitty with Deployable {
    owner: Address;
    currentLoan: Address?;
    lastLoan: Address?;

    init(owner: Address) {
        self.owner = owner;
    }

    receive(msg: KittyLoan) {
        let ctx: Context = context();
        require(ctx.value >= ton("0.3"), "At least 0.3 TON");
        require(msg.amount > 0, "Amount must be positive");

        let wallet: StateInit = initOf KittyWallet(sender(), self.owner);
        let loan: StateInit = initOf Loan(myAddress(), sender(), msg.amount);

        send(SendParameters{
            to: contractAddress(loan), 
            value: ton("0.055"),
            bounce: true,
            body: TokenTransfer{
                query_id: 0,
                amount: msg.amount,
                destination: contractAddress(loan),
                response_destination: myAddress(),
                custom_payload: emptyCell(),
                forward_ton_amount: 0,
                forward_payload: emptySlice()
            }.toCell(),
            code: wallet.code,
            data: wallet.data
        });
    }

    receive(msg: NewLoan) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not allowed to set new loan");
        require(self.currentLoan != null, "Current loan not set");

        let loan: StateInit = initOf Loan(self.owner, msg.lender, msg.amount);
        send(SendParameters{
            to: contractAddress(self.currentLoan),
            value: ton("0.055"),
            bounce: true,
            body: SetNextLoan {
                nextLoan: contractAddress(loan)
            }.toCell(),
            code: loan.code,
            data: loan.data
        });
    }

    receive(msg: BuyTickets) {
        let ctx: Context = context();
        require(ctx.value >= ton("0.2"), "At least 0.2 TON");

        let kittyMinter: StateInit = initOf KittyJetton(self.owner);

        send(SendParameters{
            to: contractAddress(kittyMinter),
            value: ton("0.15"),
            bounce: false,
            body: InternalMint {
                amount: ctx.value,
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