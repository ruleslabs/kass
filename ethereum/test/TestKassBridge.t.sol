// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "./utils/TestBase.sol";
import "./utils/Constants.sol";

contract TestTokenDeployer is KassTestBase {

    //
    // Setup
    //

    // Native withdraw

    function _prepareERC721Withdraw(
        bytes32 nativeTokenAddress,
        ERC721 erc721,
        address sender,
        uint256 tokenId,
        bool requestWrapper
    ) internal returns (uint256[] memory messagePayload) {
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 amount = 0x1;

        erc721.approve(address(_kassBridge), tokenId);

        // we begin by depositing token on starknet
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            false
        );

        // deposit them back to ethereum
        messagePayload = _expectWithdraw(
            nativeTokenAddress,
            sender,
            tokenId,
            amount,
            TokenStandard.ERC721,
            requestWrapper
        );
    }

    function _prepareERC1155Withdraw(
        bytes32 nativeTokenAddress,
        ERC1155 erc1155,
        address sender,
        uint256 tokenId,
        uint256 depositedAmount,
        bool requestWrapper
    ) internal returns (uint256[] memory messagePayload) {
        uint256 l2Recipient = Constants.L2_RANDO_1();

        erc1155.setApprovalForAll(address(_kassBridge), true);

        // we begin by depositing token on starknet
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            false
        );

        // deposit them back to ethereum
        messagePayload = _expectWithdraw(
            nativeTokenAddress,
            sender,
            tokenId,
            depositedAmount,
            TokenStandard.ERC1155,
            requestWrapper
        );
    }

    //
    // Tests
    //

    // Setup

    function testUpdateL2KassAddress() public {
        _kassBridge.setL2KassAddress(0xdead);
        assertEq(_kassBridge.l2KassAddress(), 0xdead);
    }

    function testCannotUpdateL2KassAddressIfNotOwner() public {
        vm.prank(address(0x42));
        vm.expectRevert("Ownable: caller is not the owner");
        _kassBridge.setL2KassAddress(0xdead);
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert("Already initialized");
        _kassBridge.initialize(
            abi.encodeWithSelector(KassBridge.initialize.selector, abi.encode(uint256(0x0), address(0x0)))
        );
    }

    function testUpgradeImplementation() public {
        address newImplementation = address(new KassBridge());

        assertEq(_kassBridge.l2KassAddress(), Constants.L2_KASS_ADDRESS());
        assertEq(_kassBridge.proxyImplementationAddress(), _proxyImplementationAddress);
        assertEq(_kassBridge.erc721ImplementationAddress(), _erc721ImplementationAddress);
        assertEq(_kassBridge.erc1155ImplementationAddress(), _erc1155ImplementationAddress);

        _kassBridge.upgradeToAndCall(
            newImplementation,
            abi.encodeWithSelector(
                KassBridge.initialize.selector,
                abi.encode(
                    address(this),
                    uint256(0x0),
                    address(0x0),
                    _erc1155ImplementationAddress,
                    _erc721ImplementationAddress,
                    _erc1155ImplementationAddress
                )
            )
        );

        assertEq(_kassBridge.l2KassAddress(), 0x0);
        assertEq(_kassBridge.proxyImplementationAddress(), _erc1155ImplementationAddress);
        assertEq(_kassBridge.erc721ImplementationAddress(), _erc721ImplementationAddress);
        assertEq(_kassBridge.erc1155ImplementationAddress(), _erc1155ImplementationAddress);
    }

    function testCannotUpgradeImplementationIfNotOwner() public {
        address newImplementation = address(new KassBridge());

        vm.prank(address(0x42));
        vm.expectRevert("Ownable: caller is not the owner");
        _kassBridge.upgradeToAndCall(
            newImplementation,
            abi.encodeWithSelector(KassBridge.initialize.selector, abi.encode(uint256(0x0), address(0x0)))
        );
    }

    function testCannotUpgradeToInvalidImplementation() public {
        vm.expectRevert();
        _kassBridge.upgradeTo(address(0xdead));
    }

    // ERC721 wrapper creation

    function testwrappedERC721Creation() public {
        KassERC721 wrappedERC721 = KassERC721(setupWrapper(TokenStandard.ERC721));

        assertEq(bytes(wrappedERC721.name()).length, bytes(Constants.L2_TOKEN_NAME()).length);
        assertEq(wrappedERC721.name(), Constants.L2_TOKEN_NAME());

        assertEq(bytes(wrappedERC721.symbol()).length, bytes(Constants.L2_TOKEN_SYMBOL()).length);
        assertEq(wrappedERC721.symbol(), Constants.L2_TOKEN_SYMBOL());
    }

    function testERC721DoubleWrapperCreation() public {
        setupWrapper(TokenStandard.ERC721, 0x1);
        setupWrapper(TokenStandard.ERC721, 0x2);
    }

    // ERC1155 wrapper creation

    function testwrappedERC1155Creation() public {
        KassERC1155 wrappedERC1155 = KassERC1155(setupWrapper(TokenStandard.ERC1155));

        assertEq(wrappedERC1155.uri(0), string(KassUtils.felt252WordsToStr(Constants.L2_TOKEN_URI())));
    }

    function testERC1155DoubleWrapperCreation() public {
        setupWrapper(TokenStandard.ERC1155);
        setupWrapper(TokenStandard.ERC1155);
    }

    // ERC721 wrapper request

    function testwrappedERC721Request() public {
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        bool requestWrapper = true;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721.approve(address(_kassBridge), tokenId);

        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );
    }

    // ERC1155 wrapper request

    function testwrappedERC1155Request() public {
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        bool requestWrapper = true;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155.setApprovalForAll(address(_kassBridge), true);

        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            amount,
            requestWrapper
        );
    }

    // Claim Ownership

    function testERC721ClaimOwnership() public {
        KassERC721 wrappedERC721 = KassERC721(setupWrapper(TokenStandard.ERC721));

        uint256 l2TokenAddress = Constants.L2_TOKEN_ADDRESS();
        address l1Owner = address(this);

        // claim ownership
        _starknet.requestOwnership(l2TokenAddress, l1Owner);

        _expectOwnershipClaim(l2TokenAddress, l1Owner);
        _kassBridge.claimOwnership(l2TokenAddress, l1Owner);

        assertEq(wrappedERC721.owner(), l1Owner);
    }

    function testERC1155ClaimOwnership() public {
        KassERC1155 wrappedERC1155 = KassERC1155(setupWrapper(TokenStandard.ERC1155));

        uint256 l2TokenAddress = Constants.L2_TOKEN_ADDRESS();
        address l1Owner = address(this);

        // claim ownership
        _starknet.requestOwnership(l2TokenAddress, l1Owner);

        _expectOwnershipClaim(l2TokenAddress, l1Owner);
        _kassBridge.claimOwnership(l2TokenAddress, l1Owner);

        assertEq(wrappedERC1155.owner(), l1Owner);
    }

    // Request Ownership

    function testERC721RequestOwnership() public {
        uint256 l2Owner = Constants.L2_RANDO_1();

        // request ownership
        _expectOwnershipRequest(address(_erc721), l2Owner);
        _kassBridge.requestOwnership{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(address(_erc721), l2Owner);
    }

    function testERC721CannotRequestOwnershipOnL2IfNotOwner() public {
        uint256 l2Owner = Constants.L2_RANDO_1();
        address sender = Constants.RANDO_1();
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();

        // give ether to sender for msg fees
        vm.deal(sender, 1 ether);

        // request ownership
        vm.prank(sender);
        vm.expectRevert("Sender is not the owner");
        _kassBridge.requestOwnership{ value: msgFee }(address(_erc721), l2Owner);
    }

    function testERC1155RequestOwnership() public {
        uint256 l2Owner = Constants.L2_RANDO_1();

        // request ownership
        _expectOwnershipRequest(address(_erc1155), l2Owner);
        _kassBridge.requestOwnership{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(address(_erc1155), l2Owner);
    }

    function testERC1155CannotRequestOwnershipOnL2IfNotOwner() public {
        uint256 l2Owner = Constants.L2_RANDO_1();
        address sender = Constants.RANDO_1();
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();

        // give ether to sender for msg fees
        vm.deal(sender, 1 ether);

        // request ownership
        vm.prank(sender);
        vm.expectRevert("Sender is not the owner");
        _kassBridge.requestOwnership{ value: msgFee }(address(_erc1155), l2Owner);
    }

    // Deposit L1 native ERC721 token

    function _erc721NativeTokenDeposit(
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        bool requestWrapper,
        uint256 nonce
    ) private {
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));
        uint256 amount = 0x1;

        _beforeERC721Deposit(_erc721, sender, tokenId);

        // approve kass operator
        _erc721.approve(address(_kassBridge), tokenId);

        // deposit
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        _afterERC721NativeDeposit(_erc721, tokenId);
    }

    function testERC721NativeTokenDeposit() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721NativeTokenDeposit(sender, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721NativeTokenDepositWithWrapperRequest() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = true;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721NativeTokenDeposit(sender, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721NativeTokenDepositWithHugeVariables() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        bool requestWrapper = true;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721NativeTokenDeposit(sender, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721NativeTokenDepositUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = false;
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();
        address tokenOwner = Constants.RANDO_1();

        // transfer token to someone else
        _erc721.transferFrom(sender, tokenOwner, tokenId);

        _beforeERC721Deposit(_erc721, tokenOwner, tokenId);

        // approve kass operator
        vm.prank(tokenOwner);
        _erc721.approve(address(_kassBridge), tokenId);

        // deposit
        vm.expectRevert("ERC721: transfer from incorrect owner");
        _kassBridge.deposit{ value: msgFee }(nativeTokenAddress, l2Recipient, tokenId, requestWrapper);
    }

    // Deposit L1 native ERC1155 token

    function _erc1155NativeTokenDeposit(
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint amount,
        uint256 depositedAmount,
        bool requestWrapper,
        uint256 nonce
    ) private {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));

        _beforeERC1155Deposit(_erc1155, sender, tokenId, amount);

        // approve kass operator
        _erc1155.setApprovalForAll(address(_kassBridge), true);

        // deposit
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        _afterERC1155NativeDeposit(_erc1155, sender, tokenId, amount, depositedAmount);
    }

    function testERC1155NativeTokenDeposit() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155NativeTokenDeposit(sender, l2Recipient, tokenId, amount, depositedAmount, requestWrapper, nonce);
    }

    function testERC1155NativeTokenDepositWithWrapperRequest() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = true;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155NativeTokenDeposit(sender, l2Recipient, tokenId, amount, depositedAmount, requestWrapper, nonce);
    }

    function testERC1155NativeTokenDepositWithHugeVariables() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 amount = Constants.HUGE_TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.HUGE_TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = true;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155NativeTokenDeposit(sender, l2Recipient, tokenId, amount, depositedAmount, requestWrapper, nonce);
    }

    function testERC1155NativeTokenDepositTwice() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount1 = Constants.TOKEN_AMOUNT_TO_DEPOSIT() - 1;
        uint256 depositedAmount2 = Constants.TOKEN_AMOUNT_TO_DEPOSIT() - 2;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _beforeERC1155Deposit(_erc1155, sender, tokenId, amount);

        // approve kass operator
        _erc1155.setApprovalForAll(address(_kassBridge), true);

        // deposit
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount1, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount1,
            requestWrapper
        );

        _afterERC1155NativeDeposit(_erc1155, sender, tokenId, amount, depositedAmount1);

        // 2nd deposit
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount2, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount2,
            requestWrapper
        );

        _afterERC1155NativeDeposit(_erc1155, sender, tokenId, amount, depositedAmount1 + depositedAmount2);
    }

    function testERC1155NativeTokenDepositZero() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = 0;
        bool requestWrapper = false;
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();

        _beforeERC1155Deposit(_erc1155, sender, tokenId, amount);

        // approve kass operator
        _erc1155.setApprovalForAll(address(_kassBridge), true);

        // deposit
        vm.expectRevert("Cannot deposit null amount");
        _kassBridge.deposit{ value: msgFee }(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper);
    }

    function testERC1155NativeTokenDepositUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = amount + 1;
        bool requestWrapper = false;
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();

        _beforeERC1155Deposit(_erc1155, sender, tokenId, amount);

        // approve kass operator
        _erc1155.setApprovalForAll(address(_kassBridge), true);

        // deposit
        vm.expectRevert("ERC1155: insufficient balance for transfer");
        _kassBridge.deposit{ value: msgFee }(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper);
    }

    // Deposit L2 native ERC721 token

    function _wrappedERC721Deposit(
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    ) private {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        bool requestWrapper = false;

        // setup wrapper
        ERC721 wrappedERC721 = ERC721(setupWrapper(TokenStandard.ERC721, tokenId, amount));

        _beforeERC721Deposit(wrappedERC721, sender, tokenId);

        // deposit
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        _afterWrappedERC721Deposit(wrappedERC721, tokenId);
    }

    function testwrappedERC721Deposit() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _wrappedERC721Deposit(sender, l2Recipient, tokenId, amount, nonce);
    }

    function testwrappedERC721DepositWithHugeVariables() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 amount = 0x1;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _wrappedERC721Deposit(sender, l2Recipient, tokenId, amount, nonce);
    }

    function testwrappedERC721DepositWithWrapperRequest() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = true;
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();

        // setup wrapper
        setupWrapper(TokenStandard.ERC721, tokenId, amount);

        // deposit
        vm.expectRevert("Kass: Double wrap not allowed");
        _kassBridge.deposit{ value: msgFee }(nativeTokenAddress, l2Recipient, tokenId, requestWrapper);
    }

    function testwrappedERC721DepositUnauthorized() public {
        address sender = Constants.RANDO_1();
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = false;
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();

        // setup wrapper
        setupWrapper(TokenStandard.ERC721, tokenId, amount);

        // give ether to sender for msg fees
        vm.deal(sender, 1 ether);

        // deposit
        vm.prank(sender);
        vm.expectRevert("You do not own this token");
        _kassBridge.deposit{ value: msgFee }(nativeTokenAddress, l2Recipient, tokenId, requestWrapper);
    }

    // Deposit L2 native ERC1155 token

    function _wrappedERC1155Deposit(
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 depositedAmount,
        uint256 nonce
    ) private {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        bool requestWrapper = false;

        // setup wrapper
        ERC1155 wrappedERC1155 = ERC1155(setupWrapper(TokenStandard.ERC1155, tokenId, amount));

        _beforeERC1155Deposit(wrappedERC1155, sender, tokenId, amount);

        // deposit
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        _afterWrappedERC1155Deposit(wrappedERC1155, sender, tokenId, amount, depositedAmount);
    }

    function testwrappedERC1155Deposit() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _wrappedERC1155Deposit(sender, l2Recipient, tokenId, amount, depositedAmount, nonce);
    }

    function testwrappedERC1155DepositWithHugeVariables() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 amount = Constants.HUGE_TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.HUGE_TOKEN_AMOUNT_TO_DEPOSIT();
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _wrappedERC1155Deposit(sender, l2Recipient, tokenId, amount, depositedAmount, nonce);
    }

    function testwrappedERC1155DepositWithWrapperRequest() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = true;
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();

        // setup wrapper
        setupWrapper(TokenStandard.ERC1155, tokenId, amount);

        // deposit
        vm.expectRevert("Kass: Double wrap not allowed");
        _kassBridge.deposit{ value: msgFee }(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper);
    }

    function testwrappedERC1155DepositTwice() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount1 = Constants.TOKEN_AMOUNT_TO_DEPOSIT() - 1;
        uint256 depositedAmount2 = Constants.TOKEN_AMOUNT_TO_DEPOSIT() - 2;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        // setup wrapper
        ERC1155 wrappedERC1155 = ERC1155(setupWrapper(TokenStandard.ERC1155, tokenId, amount));

        _beforeERC1155Deposit(wrappedERC1155, sender, tokenId, amount);

        // deposit
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount1, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount1,
            requestWrapper
        );

        _afterWrappedERC1155Deposit(wrappedERC1155, sender, tokenId, amount, depositedAmount1);

        // deposit
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount2, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount2,
            requestWrapper
        );

        _afterWrappedERC1155Deposit(wrappedERC1155, sender, tokenId, amount, depositedAmount1 + depositedAmount2);
    }

    function testwrappedERC1155DepositZero() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = 0;
        bool requestWrapper = false;
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();

        // setup wrapper
        setupWrapper(TokenStandard.ERC1155, tokenId, amount);

        // deposit
        vm.expectRevert("Cannot deposit null amount");
        _kassBridge.deposit{ value: msgFee }(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper);
    }

    function testwrappedERC1155DepositUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = amount + 1;
        bool requestWrapper = false;
        uint256 msgFee = Constants.L1_TO_L2_MESSAGE_FEE();

        // setup wrapper
        setupWrapper(TokenStandard.ERC1155, tokenId, amount);

        // deposit
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        _kassBridge.deposit{ value: msgFee }(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper);
    }

    // Withdraw L1 Native ERC721

    function _erc721NativeWithdraw(address sender, address l1Recipient, uint256 tokenId, bool requestWrapper) private {
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));

        uint256[] memory messagePayload = _prepareERC721Withdraw(
            nativeTokenAddress,
            _erc721,
            l1Recipient,
            tokenId,
            requestWrapper
        );

        _beforeERC721NativeWithdraw(_erc721, tokenId);

        // withdraw
        vm.prank(sender);
        _kassBridge.withdraw(messagePayload);

        _afterERC721Withdraw(_erc721, l1Recipient, tokenId);
    }

    function testERC721NativeWithdraw() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = false;

        _erc721NativeWithdraw(sender, l1Recipient, tokenId, requestWrapper);
    }

    function testERC721NativeWithdrawWithHugeVariables() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        bool requestWrapper = false;

        _erc721NativeWithdraw(sender, l1Recipient, tokenId, requestWrapper);
    }

    function testERC721NativeWithdrawWithWrapperRequest() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        bool requestWrapper = true;

        _erc721NativeWithdraw(sender, l1Recipient, tokenId, requestWrapper);
    }

    function testERC721NativeWithdrawFromOtherAddress() public {
        address sender = Constants.RANDO_1();
        address l1Recipient = address(this);
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = false;

        _erc721NativeWithdraw(sender, l1Recipient, tokenId, requestWrapper);
    }

    // Withdraw L1 Native ERC1155

    function _erc1155NativeWithdraw(
        address sender,
        address l1Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 depositedAmount,
        bool requestWrapper
    ) private {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));

        uint256[] memory messagePayload = _prepareERC1155Withdraw(
            nativeTokenAddress,
            _erc1155,
            l1Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        _beforeERC1155NativeWithdraw(_erc1155, l1Recipient, tokenId, amount, depositedAmount);

        // withdraw
        vm.prank(sender);
        _kassBridge.withdraw(messagePayload);

        _afterERC1155Withdraw(_erc1155, l1Recipient, tokenId, amount);
    }

    function testERC1155NativeWithdraw() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;

        _erc1155NativeWithdraw(sender, l1Recipient, tokenId, amount, depositedAmount, requestWrapper);
    }

    function testERC1155NativeWithdrawWithHugeVariables() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 amount = Constants.HUGE_TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.HUGE_TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;

        _erc1155NativeWithdraw(sender, l1Recipient, tokenId, amount, depositedAmount, requestWrapper);
    }

    function testERC1155NativeWithdrawWithWrapperRequest() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = true;

        _erc1155NativeWithdraw(sender, l1Recipient, tokenId, amount, depositedAmount, requestWrapper);
    }

    function testERC1155NativeWithdrawFromOtherAddress() public {
        address sender = Constants.RANDO_1();
        address l1Recipient = address(this);
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;

        _erc1155NativeWithdraw(sender, l1Recipient, tokenId, amount, depositedAmount, requestWrapper);
    }

    function testERC1155NativeWithdrawTwice() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        address l1Recipient = address(this);
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount1 = Constants.TOKEN_AMOUNT_TO_DEPOSIT() - 1;
        uint256 depositedAmount2 = Constants.TOKEN_AMOUNT_TO_DEPOSIT() - 2;
        bool requestWrapper = false;

        uint256[] memory messagePayload1 = _prepareERC1155Withdraw(
            nativeTokenAddress,
            _erc1155,
            l1Recipient,
            tokenId,
            depositedAmount1,
            requestWrapper
        );
        uint256[] memory messagePayload2 = _prepareERC1155Withdraw(
            nativeTokenAddress,
            _erc1155,
            l1Recipient,
            tokenId,
            depositedAmount2,
            requestWrapper
        );

        // withdraw 1
        _beforeERC1155NativeWithdraw(_erc1155, l1Recipient, tokenId, amount, depositedAmount1 + depositedAmount2);

        // withdraw
        _kassBridge.withdraw(messagePayload1);

        _afterERC1155Withdraw(_erc1155, l1Recipient, tokenId, amount - depositedAmount2);

        // withdraw 2
        _beforeERC1155NativeWithdraw(_erc1155, l1Recipient, tokenId, amount, depositedAmount2);

        // withdraw
        _kassBridge.withdraw(messagePayload2);

        _afterERC1155Withdraw(_erc1155, l1Recipient, tokenId, amount);
    }

    // Withdraw L2 Native ERC721

    function _erc21WrapperWithdraw(address sender, address l1Recipient, uint256 tokenId, bool requestWrapper) private {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());

        // setup wrapper
        ERC721 wrappedERC721 = ERC721(setupWrapper(TokenStandard.ERC721, tokenId));

        // prepare withdraw
        uint256[] memory messagePayload = _prepareERC721Withdraw(
            nativeTokenAddress,
            wrappedERC721,
            l1Recipient,
            tokenId,
            requestWrapper
        );

        _beforeWrappedERC721Withdraw(wrappedERC721, tokenId);

        // withdraw
        vm.prank(sender);
        _kassBridge.withdraw(messagePayload);

        _afterERC721Withdraw(wrappedERC721, l1Recipient, tokenId);
    }

    function testwrappedERC721Withdraw() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = false;

        _erc21WrapperWithdraw(sender, l1Recipient, tokenId, requestWrapper);
    }

    function testwrappedERC721WithdrawWithHugeVariables() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        bool requestWrapper = false;

        _erc21WrapperWithdraw(sender, l1Recipient, tokenId, requestWrapper);
    }

    function testwrappedERC721WithdrawWithWrapperRequest() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = true;

        _erc21WrapperWithdraw(sender, l1Recipient, tokenId, requestWrapper);
    }

    function testwrappedERC721WithdrawFromOtherAddress() public {
        address sender = Constants.RANDO_1();
        address l1Recipient = address(this);
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = false;

        _erc21WrapperWithdraw(sender, l1Recipient, tokenId, requestWrapper);
    }

    // Withdraw L2 Native ERC1155

    function _wrappedERC1155Withdraw(
        address sender,
        address l1Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 depositedAmount,
        bool requestWrapper
    ) private {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());

        // setup wrapper
        ERC1155 wrappedERC1155 = ERC1155(setupWrapper(TokenStandard.ERC1155, tokenId, amount));

        // prepare withdraw
        uint256[] memory messagePayload = _prepareERC1155Withdraw(
            nativeTokenAddress,
            wrappedERC1155,
            l1Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        _beforeWrappedERC1155Withdraw(wrappedERC1155, l1Recipient, tokenId, amount, depositedAmount);

        // withdraw
        vm.prank(sender);
        _kassBridge.withdraw(messagePayload);

        _afterERC1155Withdraw(wrappedERC1155, l1Recipient, tokenId, amount);
    }

    function testwrappedERC1155Withdraw() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;

        _wrappedERC1155Withdraw(sender, l1Recipient, tokenId, amount, depositedAmount, requestWrapper);
    }

    function testwrappedERC1155WithdrawWithHugeVariables() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 amount = Constants.HUGE_TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.HUGE_TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;

        _wrappedERC1155Withdraw(sender, l1Recipient, tokenId, amount, depositedAmount, requestWrapper);
    }

    function testwrappedERC1155WithdrawWithWrapperRequest() public {
        address sender = address(this);
        address l1Recipient = sender;
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = true;

        _wrappedERC1155Withdraw(sender, l1Recipient, tokenId, amount, depositedAmount, requestWrapper);
    }

    function testwrappedERC1155WithdrawFromOtherAddress() public {
        address sender = Constants.RANDO_1();
        address l1Recipient = address(this);
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;

        _wrappedERC1155Withdraw(sender, l1Recipient, tokenId, amount, depositedAmount, requestWrapper);
    }

    function testwrappedERC1155WithdrawTwice() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address l1Recipient = address(this);
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount1 = Constants.TOKEN_AMOUNT_TO_DEPOSIT() - 1;
        uint256 depositedAmount2 = Constants.TOKEN_AMOUNT_TO_DEPOSIT() - 2;
        bool requestWrapper = false;

        // setup wrapper
        ERC1155 wrappedERC1155 = ERC1155(setupWrapper(TokenStandard.ERC1155, tokenId, amount));

        // prepare withdraws
        uint256[] memory messagePayload1 = _prepareERC1155Withdraw(
            nativeTokenAddress,
            wrappedERC1155,
            l1Recipient,
            tokenId,
            depositedAmount1,
            requestWrapper
        );
        uint256[] memory messagePayload2 = _prepareERC1155Withdraw(
            nativeTokenAddress,
            wrappedERC1155,
            l1Recipient,
            tokenId,
            depositedAmount2,
            requestWrapper
        );

        // withdraw 1
        _beforeWrappedERC1155Withdraw(
            wrappedERC1155,
            l1Recipient,
            tokenId,
            amount,
            depositedAmount1 + depositedAmount2
        );

        // withdraw
        _kassBridge.withdraw(messagePayload1);

        _afterERC1155Withdraw(wrappedERC1155, l1Recipient, tokenId, amount - depositedAmount2);

        // withdraw 2
        _beforeWrappedERC1155Withdraw(
            wrappedERC1155,
            l1Recipient,
            tokenId,
            amount,
            depositedAmount2
        );

        // withdraw
        _kassBridge.withdraw(messagePayload2);

        _afterERC1155Withdraw(wrappedERC1155, l1Recipient, tokenId, amount);
    }

    // L1 Native ERC721 Deposit cancel

    function _erc721NativeDepositCancel(
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        bool requestWrapper,
        uint256 nonce
    ) private {
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));
        uint256 amount = 0x1;

        _erc721.approve(address(_kassBridge), tokenId);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        _afterERC721NativeDeposit(_erc721, tokenId);

        // deposit cancel request
        _expectDepositCancelRequest(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);

        // assert token has not moved
        _afterERC721NativeDeposit(_erc721, tokenId);

        // deposit cancel request
        _expectDepositCancel(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);

        // check if owner is correct
        _beforeERC721Deposit(_erc721, sender, tokenId);
    }

    function testERC721NativeDepositCancel() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721NativeDepositCancel(sender, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721NativeDepositCancelWithHugeVariables() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        bool requestWrapper = false;
        uint256 nonce = Constants.HUGE_L1_TO_L2_MESSAGE_NONCE();

        _erc721NativeDepositCancel(sender, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721NativeDepositCancelWithWrapperRequest() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        bool requestWrapper = true;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721NativeDepositCancel(sender, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721NativeRequestDepositCancelUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));
        address sender = address(this);
        address fakeSender = Constants.RANDO_1();
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721.approve(address(_kassBridge), tokenId);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        vm.prank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721NativeCancelDepositUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));
        address sender = address(this);
        address fakeSender = Constants.RANDO_1();
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721.approve(address(_kassBridge), tokenId);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        // deposit cancel request
        _expectDepositCancelRequest(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);

        // deposit cancel request
        vm.prank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721NativeRequestDepositCancelInvalidNonce() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721.approve(address(_kassBridge), tokenId);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        vm.expectRevert("Deposit not found");
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce + 1);
    }

    function testERC721NativeCancelDepositInvalidNonce() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc721));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc721.approve(address(_kassBridge), tokenId);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        // deposit cancel request
        _expectDepositCancelRequest(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);

        // deposit cancel request
        vm.expectRevert("Deposit not found");
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce + 1);
    }

    // L1 Native ERC1155 Deposit cancel

    function _erc1155NativeDepositCancel(
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 depositedAmount,
        bool requestWrapper,
        uint256 nonce
    ) private {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));

        _erc1155.setApprovalForAll(address(_kassBridge), true);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        _afterERC1155NativeDeposit(_erc1155, sender, tokenId, amount, depositedAmount);

        // deposit cancel request
        _expectDepositCancelRequest(
            nativeTokenAddress,
            sender,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );

        // assert token has not moved
        _afterERC1155NativeDeposit(_erc1155, sender, tokenId, amount, depositedAmount);

        // deposit cancel request
        _expectDepositCancel(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);

        // check if owner is correct
        _beforeERC1155Deposit(_erc1155, sender, tokenId, amount);
    }

    function testERC1155NativeDepositCancel() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155NativeDepositCancel(sender, l2Recipient, tokenId, amount, depositedAmount, requestWrapper, nonce);
    }

    function testERC1155NativeDepositCancelWithHugeVariables() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 amount = Constants.HUGE_TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.HUGE_TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.HUGE_L1_TO_L2_MESSAGE_NONCE();

        _erc1155NativeDepositCancel(sender, l2Recipient, tokenId, amount, depositedAmount, requestWrapper, nonce);
    }

    function testERC1155NativeDepositCancelWithWrapperRequest() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = true;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155NativeDepositCancel(sender, l2Recipient, tokenId, amount, depositedAmount, requestWrapper, nonce);
    }

    function testERC1155NativeRequestDepositCancelUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        address sender = address(this);
        address fakeSender = Constants.RANDO_1();
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155.setApprovalForAll(address(_kassBridge), true);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        vm.prank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );
    }

    function testERC1155NativeCancelDepositUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        address sender = address(this);
        address fakeSender = Constants.RANDO_1();
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155.setApprovalForAll(address(_kassBridge), true);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        // deposit cancel request
        _expectDepositCancelRequest(
            nativeTokenAddress,
            sender,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );

        // deposit cancel request
        vm.prank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
    }

    function testERC1155NativeRequestDepositCancelInvalidNonce() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155.setApprovalForAll(address(_kassBridge), true);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        vm.expectRevert("Deposit not found");
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce + 1
        );
    }

    function testERC1155NativeCancelDepositInvalidNonce() public {
        bytes32 nativeTokenAddress = _bytes32(address(_erc1155));
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _erc1155.setApprovalForAll(address(_kassBridge), true);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        // deposit cancel request
        _expectDepositCancelRequest(
            nativeTokenAddress,
            sender,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );

        // deposit cancel request
        vm.expectRevert("Deposit not found");
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce + 1);
    }

    // L2 Native ERC721 Deposit cancel

    function _wrappedERC721DepositCancel(
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 nonce
    ) private {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        uint256 amount = 0x1;
        bool requestWrapper = false;

        ERC721 wrappedERC721 = ERC721(setupWrapper(TokenStandard.ERC721, tokenId));

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        _afterWrappedERC721Deposit(wrappedERC721, tokenId);

        // deposit cancel request
        _expectDepositCancelRequest(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);

        // assert token has not moved
        _afterWrappedERC721Deposit(wrappedERC721, tokenId);

        // deposit cancel request
        _expectDepositCancel(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);

        // check if owner is correct
        _beforeERC721Deposit(wrappedERC721, sender, tokenId);
    }

    function testERC721WrapperDepositCancel() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _wrappedERC721DepositCancel(sender, l2Recipient, tokenId, nonce);
    }

    function testERC721WrapperDepositCancelWithHugeVariables() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 nonce = Constants.HUGE_L1_TO_L2_MESSAGE_NONCE();

        _wrappedERC721DepositCancel(sender, l2Recipient, tokenId, nonce);
    }

    function testERC721WrapperRequestDepositCancelUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address sender = address(this);
        address fakeSender = Constants.RANDO_1();
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        setupWrapper(TokenStandard.ERC721, tokenId);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        vm.prank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721WrapperCancelDepositUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address sender = address(this);
        address fakeSender = Constants.RANDO_1();
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        setupWrapper(TokenStandard.ERC721, tokenId);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        // deposit cancel request
        _expectDepositCancelRequest(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);

        // deposit cancel request
        vm.prank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);
    }

    function testERC721WrapperRequestDepositCancelInvalidNonce() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        setupWrapper(TokenStandard.ERC721, tokenId);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        vm.expectRevert("Deposit not found");
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce + 1);
    }

    function testERC721WrapperCancelDepositInvalidNonce() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = 0x1;
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        setupWrapper(TokenStandard.ERC721, tokenId);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            requestWrapper
        );

        // deposit cancel request
        _expectDepositCancelRequest(nativeTokenAddress, sender, l2Recipient, tokenId, amount, requestWrapper, nonce);
        _kassBridge.requestDepositCancel(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce);

        // deposit cancel request
        vm.expectRevert("Deposit not found");
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, requestWrapper, nonce + 1);
    }

    // L2 Native ERC1155 Deposit cancel

    function _wrappedERC1155DepositCancel(
        address sender,
        uint256 l2Recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 depositedAmount,
        uint256 nonce
    ) private {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        bool requestWrapper = false;

        ERC1155 wrappedERC1155 = ERC1155(setupWrapper(TokenStandard.ERC1155, tokenId, amount));

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        _afterWrappedERC1155Deposit(wrappedERC1155, sender, tokenId, amount, depositedAmount);

        // deposit cancel request
        _expectDepositCancelRequest(
            nativeTokenAddress,
            sender,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );

        // assert token has not moved
        _afterWrappedERC1155Deposit(wrappedERC1155, sender, tokenId, amount, depositedAmount);

        // deposit cancel request
        _expectDepositCancel(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);

        // check if owner is correct
        _beforeERC1155Deposit(wrappedERC1155, sender, tokenId, amount);
    }

    function testERC1155WrapperDepositCancel() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        _wrappedERC1155DepositCancel(sender, l2Recipient, tokenId, amount, depositedAmount, nonce);
    }

    function testERC1155WrapperDepositCancelWithHugeVariables() public {
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.HUGE_TOKEN_ID();
        uint256 amount = Constants.HUGE_TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.HUGE_TOKEN_AMOUNT_TO_DEPOSIT();
        uint256 nonce = Constants.HUGE_L1_TO_L2_MESSAGE_NONCE();

        _wrappedERC1155DepositCancel(sender, l2Recipient, tokenId, amount, depositedAmount, nonce);
    }

    function testERC1155WrapperRequestDepositCancelUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address sender = address(this);
        address fakeSender = Constants.RANDO_1();
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        setupWrapper(TokenStandard.ERC1155, tokenId, amount);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        vm.prank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );
    }

    function testERC1155WrapperCancelDepositUnauthorized() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address sender = address(this);
        address fakeSender = Constants.RANDO_1();
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        setupWrapper(TokenStandard.ERC1155, tokenId, amount);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        // deposit cancel request
        _expectDepositCancelRequest(
            nativeTokenAddress,
            sender,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );

        // deposit cancel request
        vm.prank(fakeSender);
        vm.expectRevert("Caller is not the depositor");
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
    }

    function testERC1155WrapperRequestDepositCancelInvalidNonce() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        setupWrapper(TokenStandard.ERC1155, tokenId, amount);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        vm.expectRevert("Deposit not found");
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce + 1
        );
    }

    function testERC1155WrapperCancelDepositInvalidNonce() public {
        bytes32 nativeTokenAddress = _bytes32(Constants.L2_TOKEN_ADDRESS());
        address sender = address(this);
        uint256 l2Recipient = Constants.L2_RANDO_1();
        uint256 tokenId = Constants.TOKEN_ID();
        uint256 amount = Constants.TOKEN_AMOUNT();
        uint256 depositedAmount = Constants.TOKEN_AMOUNT_TO_DEPOSIT();
        bool requestWrapper = false;
        uint256 nonce = Constants.L1_TO_L2_MESSAGE_NONCE();

        setupWrapper(TokenStandard.ERC1155, tokenId, amount);

        // we begin by depositing token on starknet
        _expectDeposit(nativeTokenAddress, sender, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce);
        _kassBridge.deposit{ value: Constants.L1_TO_L2_MESSAGE_FEE() }(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper
        );

        // deposit cancel request
        _expectDepositCancelRequest(
            nativeTokenAddress,
            sender,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );
        _kassBridge.requestDepositCancel(
            nativeTokenAddress,
            l2Recipient,
            tokenId,
            depositedAmount,
            requestWrapper,
            nonce
        );

        // deposit cancel request
        vm.expectRevert("Deposit not found");
        _kassBridge.cancelDeposit(nativeTokenAddress, l2Recipient, tokenId, depositedAmount, requestWrapper, nonce + 1);
    }

    //
    // Helpers
    //

    // Deposit ERC721

    function _beforeERC721Deposit(ERC721 token, address depositor, uint256 tokenId) private {
        // assert depositor owns token
        assertEq(token.ownerOf(tokenId), depositor);
    }

    function _afterERC721NativeDeposit(ERC721 token, uint256 tokenId) private {
        // assert bridge owns token
        assertEq(token.ownerOf(tokenId), address(_kassBridge));
    }

    function _afterWrappedERC721Deposit(ERC721 token, uint256 tokenId) private {
        // assert token has been burned
        vm.expectRevert("ERC721: invalid token ID");
        token.ownerOf(tokenId);
    }

    // Deposit ERC1155

    function _beforeERC1155Deposit(ERC1155 token, address depositor, uint256 tokenId, uint256 amount) private {
        // assert depositor owns tokens
        assertEq(token.balanceOf(depositor, tokenId), amount);
    }

    function _afterERC1155NativeDeposit(
        ERC1155 token,
        address depositor,
        uint256 tokenId,
        uint256 amount,
        uint256 depositedAmount
    ) private {
        // assert depositor and bridge own tokens
        assertEq(token.balanceOf(depositor, tokenId), amount - depositedAmount);
        assertEq(token.balanceOf(address(_kassBridge), tokenId), depositedAmount);
    }

    function _afterWrappedERC1155Deposit(
        ERC1155 token,
        address depositor,
        uint256 tokenId,
        uint256 amount,
        uint256 depositedAmount
    ) private {
        // assert depositor and bridge own tokens
        assertEq(token.balanceOf(depositor, tokenId), amount - depositedAmount);
    }

    // Withdraw ERC721

    function _beforeERC721NativeWithdraw(ERC721 token, uint256 tokenId) private {
        _afterERC721NativeDeposit(token, tokenId);
    }

    function _beforeWrappedERC721Withdraw(ERC721 token, uint256 tokenId) private {
        _afterWrappedERC721Deposit(token, tokenId);
    }

    function _afterERC721Withdraw(ERC721 token, address recipient, uint256 tokenId) private {
        _beforeERC721Deposit(token, recipient, tokenId);
    }

    // Withdraw ERC1155

    function _beforeERC1155NativeWithdraw(
        ERC1155 token,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 depositedAmount
    ) private {
        _afterERC1155NativeDeposit(token, recipient, tokenId, amount, depositedAmount);
    }

    function _beforeWrappedERC1155Withdraw(
        ERC1155 token,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        uint256 depositedAmount
    ) private {
        _afterWrappedERC1155Deposit(token, recipient, tokenId, amount, depositedAmount);
    }

    function _afterERC1155Withdraw(ERC1155 token, address recipient, uint256 tokenId, uint256 amount) private {
        _beforeERC1155Deposit(token, recipient, tokenId, amount);
    }
}
