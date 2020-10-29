pragma solidity ^0.5.0;

import "../SafeMath.sol";
import "../IERC20.sol";
import "../Ownable.sol";
import "../libraries/TrxAddressLib.sol";
import "../configuration/LendingPoolAddressesProvider.sol";
import "../PriceOracle.sol";

interface ISwapProxyInterface {
    function tokenToTrxSwapInput(uint256 tokens_sold, uint256 min_trx, uint256 deadline) external returns (uint256);
    function trxToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient) external payable returns(uint256);
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline) external payable returns (uint256);
}

interface IJustFactoryInterface {
    function getExchange(address token) external view returns (address payable);
}

contract TokenDistributor is Ownable {
    using SafeMath for uint256;

    LendingPoolAddressesProvider public addressesProvider;

    event Distributed(uint distributer_amount, uint256 buy_back_amount, uint256 community_amount);

    /// @notice Defines how tokens and TRX are distributed on each call to .distribute()
    address private distributer;
    address private community;
    address public CirculateCoin;
    address public LpToken;

    /// @notice Instead of using 100 for percentages, higher base to have more precision in the distribution
    uint256 public constant DISTRIBUTION_BASE = 10000;
    uint256 public constant distributer_percent = 3000;
    uint256 public constant buy_back_percent = 3000;
    uint256 public constant community_percent = 4000;

    IJustFactoryInterface public factory;

    function contractor(LendingPoolAddressesProvider _addressesProvider, address _distributer, address _community, address _CirculateCoin) public {
        addressesProvider = _addressesProvider;
        distributer = _distributer;
        community = _community;
        CirculateCoin = _CirculateCoin;
    }

    function setLpTokenAddress(address _lpAddr) external onlyOwner {
        LpToken = _lpAddr;
    }

    function setFactory(address _factory) external onlyOwner {
        factory = IJustFactoryInterface(_factory);
        approveCirculateToExchange();
    }

    /// @notice approve CirculateCoin to exchange
    function approveCirculateToExchange() internal {
        IERC20(CirculateCoin).approve(factory.getExchange(CirculateCoin), 1e77);
    }

    /// @notice In order to receive TRX transfers
    function() external payable {}

    function SwapToTrx(address _asset, uint _amount) internal {
        ISwapProxyInterface assetFactory = ISwapProxyInterface(factory.getExchange(_asset));
        assetFactory.tokenToTrxSwapInput(_amount, 1, 10);
    }

    // Buy back and destroy
    function SwapToCoin(uint _trxCount, address _tokenToBurn, address _destAddress) internal {
        ISwapProxyInterface tokenToBurnFactory = ISwapProxyInterface(factory.getExchange(_tokenToBurn));
        tokenToBurnFactory.trxToTokenTransferInput.value(_trxCount)(1, 10, _destAddress);
    }

    // Add liquidity to the Circulate exchange
    function addCirculateLiquidity(uint _value) internal {
        ISwapProxyInterface exchange = ISwapProxyInterface(factory.getExchange(CirculateCoin));
        uint lpNum = exchange.addLiquidity.value(_value)(1, 1e77, 10);
        IERC20(LpToken).transfer(distributer, lpNum);
    }

    /// @notice Convert a list of _tokens balances in this contract into trx through the justswap
    /// @param _tokens list of tokens
    function convertedIntoTrx(IERC20[] memory _tokens) public onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            address _tokenAddress = address(_tokens[i]);
            require(_tokenAddress != TrxAddressLib.trxAddress());
            uint256 _balanceToDistribute = _tokens[i].balanceOf(address(this));
            if (_balanceToDistribute <= 0) {
                continue;
            }
            SwapToTrx(_tokenAddress, _balanceToDistribute);
        }
    }

    /// @notice Returns the receivers and percentages of the contract Distribution
    /// @dev before this, distributer need to approve enough circulateCoin to this contract
    function distribution() external {
        require(msg.sender == distributer, 'caller must be distributer');
        PriceOracle oracle = PriceOracle(addressesProvider.getPriceOracle());
        uint CirculatePrice = oracle.getAssetPrice(CirculateCoin);

        uint balance = address(this).balance;
        uint a = balance.mul(distributer_percent).div(DISTRIBUTION_BASE);
        // The first step is to transfer the corresponding coin from the caller
        IERC20(CirculateCoin).transferFrom(msg.sender, address(this), a.mul(1000000).div(CirculatePrice));
        addCirculateLiquidity(a);

        uint b = balance.mul(buy_back_percent).div(DISTRIBUTION_BASE);
        uint c = balance.sub(a).sub(b);
        SwapToCoin(b, CirculateCoin, address(0));
        (bool result, ) = community.call.value(c)("");
            require(result, "Transfer of TRX failed");
        emit Distributed(a, b, c);
    }

    /// @notice This method is called if the contract needs to be changed
    // function exitAsset(address _tokenAddress) public onlyOwner {
    //     uint256 _balanceToDistribute = (_tokenAddress != TrxAddressLib.trxAddress())
    //         ? IERC20(_tokenAddress).balanceOf(address(this))
    //         : address(this).balance;
    //     if (_balanceToDistribute > 0) {
    //         if (_tokenAddress != TrxAddressLib.trxAddress()) {
    //             IERC20(_tokenAddress).transfer(owner(), _balanceToDistribute);
    //         } else {
    //             (bool _success,) = owner().call.value(_balanceToDistribute)("");
    //             require(_success, "Reverted TRX transfer");
    //         }
    //     }
    // }
}