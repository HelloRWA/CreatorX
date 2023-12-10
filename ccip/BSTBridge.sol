// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BSTBridge is CCIPReceiver, OwnerIsCreator {
    error FailedLockToken(address token, uint256 amount);

    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        address token, // The token address that was transferred.
        address targetAddress,
        uint256 tokenAmount, // The token amount that was transferred.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the message.
    );

    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        address token, // The token address that was transferred.
        address targetAddress, // The token address that was transferred.
        uint256 tokenAmount // The token amount that was transferred.
    );

    bytes32 private s_lastReceivedMessageId; // Store the last received messageId.
    string private s_lastReceivedText; // Store the last received text.

    mapping(uint64 => mapping(address => address)) bridgeMap; // chainSelector.sourceTokenAddress.targetTokenAddress

    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;

    constructor(address _router, address _link) CCIPReceiver(_router) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
    }

    receive() external payable {}

    function sendToken(
        uint64 _destinationChainSelector,
        address _receiver,
        address _targetAddress,
        address _token,
        uint256 _amount
    )
        external
        payable
        returns (
            // ) external payable {
            bytes32 messageId
        )
    {
        (
            Client.EVM2AnyMessage memory evm2AnyMessage,
            uint fees
        ) = buildCCIPMessage(
                _destinationChainSelector,
                _receiver,
                _targetAddress,
                _token,
                _amount
            );

        // lock in to the sender
        bool payRz = IERC20(_token).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!payRz) revert FailedLockToken(_token, _amount);

        s_linkToken.approve(address(s_router), fees);
        messageId = s_router.ccipSend(
            _destinationChainSelector,
            evm2AnyMessage
        );

        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _token,
            _targetAddress,
            _amount,
            address(s_linkToken),
            fees
        );

        return messageId;
    }

    function buildCCIPMessage(
        uint64 _destinationChainSelector,
        address _receiver,
        address _targetAddress,
        address _token,
        uint256 _amount
    )
        public
        view
        returns (Client.EVM2AnyMessage memory evm2AnyMessage, uint fees)
    {
        evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: abi.encode(_token, _targetAddress, _amount), // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // The amount and type of token being transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false})
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: address(s_linkToken)
        });

        fees = s_router.getFee(_destinationChainSelector, evm2AnyMessage);
        return (evm2AnyMessage, fees);
    }

    error NoBridgeYet(bytes32 msgId, address token);

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        s_lastReceivedMessageId = any2EvmMessage.messageId; // fetch the messageId
        (address token, address targetAddress, uint256 amount) = abi.decode(
            any2EvmMessage.data,
            (address, address, uint256)
        );

        if (erc20Bridge[token] == address(0)) {
            revert NoBridgeYet(s_lastReceivedMessageId, token);
        }

        address targetToken = erc20Bridge[token];
        tokenBalanceMap[targetToken][targetAddress] += amount;

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            abi.decode(any2EvmMessage.sender, (address)), // abi-decoding of the sender address,
            token,
            targetAddress,
            amount
        );
    }

    mapping(address => mapping(address => uint)) tokenBalanceMap;

    function tokenBalance(
        address erc20Address,
        address owner
    ) public view returns (uint) {
        return tokenBalanceMap[erc20Address][owner];
    }

    error NoTokenBalance(address token, address owner);
    error NotEnoughTokenBalance(address token, uint balance, uint userBalance);
    error FailedTranferToken(address token, address user, uint userBalance);

    function withdrawToken(address erc20Address) public returns (bool) {
        address user = msg.sender;
        uint userBalance = tokenBalanceMap[erc20Address][user];
        if (userBalance == 0) {
            revert NoTokenBalance(erc20Address, user);
        }
        uint256 balance = IERC20(erc20Address).balanceOf(address(this));
        if (balance < userBalance) {
            revert NotEnoughTokenBalance(erc20Address, balance, userBalance);
        }
        tokenBalanceMap[erc20Address][user] = 0;
        bool payRz = IERC20(erc20Address).transfer(user, userBalance);
        if (!payRz) revert FailedTranferToken(erc20Address, user, userBalance);

        return true;
    }

    mapping(address => address) erc20Bridge;
    address[] bridgeSourceArr;

    function getAllBridge()
        public
        view
        returns (address[] memory sourceArr, address[] memory targetArr)
    {
        uint count = bridgeSourceArr.length;
        sourceArr = bridgeSourceArr;
        targetArr = new address[](count);

        for (uint i = 0; i < count; i++) {
            targetArr[i] = sourceArr[i];
        }
        return (sourceArr, targetArr);
    }

    function addERC20Bridge(address source, address target) public onlyOwner {
        if (erc20Bridge[source] == address(0)) {
            bridgeSourceArr.push(source);
        }

        erc20Bridge[source] = target;
    }

    function withdrawAll() public onlyOwner returns (bool send1, bool send2) {
        // Retrieve the balance of this contract
        uint256 amount1 = address(this).balance;
        address owner = msg.sender;
        if (amount1 > 0) {
            (send1, ) = owner.call{value: amount1}("");
        }

        uint256 amount2 = s_linkToken.balanceOf(address(this));
        if (amount2 > 0) {
            send2 = s_linkToken.transfer(owner, amount2);
        }
    }
}
