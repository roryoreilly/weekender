const Weekender = artifacts.require("Weekender");

contract("Weekender tests", async accounts => {
    let instance;
    before(async () => {
        instance = await Weekender.deployed();
    });

    it("should put all Weekender coints in the first account", async () => {
        let balance = await instance.balanceOf.call(accounts[0]);
        let totalCoins = await instance.totalSupply.call();
        console.log(balance);
        assert.equal(balance.valueOf(), 1020000);
    });


    it("should send tokens to other users", async () => {
        const accountsToDistribute = [accounts[1], accounts[2], accounts[3]];
        await instance.distributeToken(accountsToDistribute, 100);

        let balance = await instance.balanceOf.call(accounts[1]);
        console.log(`Balance of account: ${balance.toNumber()}`);
        assert.equal(balance.valueOf(), 100);
    });


    it("should produce the correct interest of zero", async () => {
        const now = await web3.eth.blocknumber.timestamp;
        const interest = await instance._calInterest.call(now);
        console.log(`Interest of now : ${interest}`);
        assert.equal(interest, 0);
    });
});
