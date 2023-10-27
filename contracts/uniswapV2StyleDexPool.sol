//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import './libraries/Math.sol';
import './interfaces/IERC20.sol';
import './uniswapV2StyleDexERC20.sol';

contract uniswapV2StyleDexPool is uniswapV2StyleDexERC20("uniswapV2StyleDex", "UDX", 18) {
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    address immutable public factory;
    address public token0;
    address public token1;
    uint public reserve0;
    uint public reserve1;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'uniswapV2StyleDexPool: INITIALIZATION_FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
    }

    function mint(address to) external returns (uint liquidity) {
        uint balance0 = IERC20(token0).balanceOf(address(this));  // (※5)
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - reserve0;
        uint amount1 = balance1 - reserve1;
        /*
         - (※5)
         - デプロイされたコントラクトから他のデプロイされたコントラクトの関数を遠隔で起動。
        */
        
        /*
         - ステートヴァリアブルをpublicにすると他のコントラクトで使うときゲッター関数として後ろに()つけて使うかけど、
         - このコントラクトはuniswapV2StyleDexERC20を継承してるからinternalの _totalSupply の後ろに()いらないのかな多分。
         -  _totalSupply * hoge　はいけるけど totalSupply() * hoge はダメでやるならtotalSupply()を変数に入れてからにしなきゃ
         - いけないから、それが手間で_totalSupplyをinternalにしたのかな多分。
        */
        if (_totalSupply == 0) {
            require(amount0 * amount1 > MINIMUM_LIQUIDITY * MINIMUM_LIQUIDITY, 'uniswapV2StyleDexPool: BELOW_MINIMUM_LIQUIDITY');
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(amount0 * _totalSupply / reserve0, amount1 * _totalSupply / reserve1);  //(※1)
        }
        require(liquidity > 0, 'uniswapV2StyleDexPool: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);
        reserve0 = balance0;
        reserve1 = balance1;
        emit Mint (msg.sender, amount0, amount1);

        /*
         - (※1)amount0 * _totalSupply / reserve0　について。整数の除算の結果は小数点以下切り捨てとなるのだろうか。
         = 追記: おそらく切り捨てられる。(リテラル同士の除算では、任意の精度で小数点以下も結果に含まれるとか)
        */
    }
    
    function burn (address to) external returns(uint amount0, uint amount1) {
        IERC20 token0Contract = IERC20(token0);
        IERC20 token1Contract = IERC20(token1);
        
        uint liquidity = _balances[address(this)];
        uint balance0 = token0Contract.balanceOf(address(this));
        uint balance1 = token1Contract.balanceOf(address(this));
        amount0 = balance0 * liquidity / _totalSupply;
        amount1 = balance1 * liquidity / _totalSupply;
        require(amount0 > 0 && amount1 > 0, 'uniswapV2StyleDexPool: INSUFFICIENT_LIQUIDITY_BURNED');

        _burn(address(this), liquidity);
        bool success0 = token0Contract.transfer(to, amount0);
        require(success0, 'uniswapV2StyleDexPool: TOKEN0_TRANSFER_FAILED');
        bool success1 = token1Contract.transfer(to, amount1);
        require(success1, 'uniswapV2StyleDexPool: TOKEN1_TRANSFER_FAILED');

        reserve0 = token0Contract.balanceOf(address(this));
        reserve1 = token1Contract.balanceOf(address(this));

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint amount0Out, uint amount1Out, address to) external {
        require(amount0Out > 0 || amount1Out > 0, 'uniswapV2StyleDexPool: INSUFFICIENT_OUTPUT_AMOUNT');
        require(amount0Out < reserve0 && amount1Out < reserve1, 'uniswapV2StyleDexPool: INSUFFICIENT_LIQUIDITY');
        require(to != token0 && to != token1, 'uniswapV2StyleDexPool: INVALID_TO');

        uint balance0;
        uint balance1;

        {
        IERC20 token0Contract = IERC20(token0);
        IERC20 token1Contract = IERC20(token1);
        if(amount0Out > 0) {
            bool success0 = token0Contract.transfer(to, amount0Out);
            require(success0, 'uniswapV2StyleDexPool: TOKEN0_TRANSFER_FAILED');
        }
        if(amount1Out > 0) {
            bool success1 = token1Contract.transfer(to, amount1Out);
            require(success1, 'uniswapV2StyleDexPool: TOKEN1_TRANSFER_FAILED');
        }
        balance0 = token0Contract.balanceOf(address(this));
        balance1 = token1Contract.balanceOf(address(this));
        }

        uint amount0In = balance0 > reserve0 - amount0Out ? balance0 - (reserve0 - amount0Out) : 0; //(※1)
        uint amount1In = balance1 > reserve1 - amount1Out ? balance1 - (reserve1 - amount1Out) : 0; //(※2)
        require(amount0In > 0 || amount1In > 0, 'uniswapV2StyleDexPool: INSUFFICIENT_INPUT_AMOUNT');
        /*
         - (※1,2) "?" 側が採用されるとき最後の "= amount1Out" は 0 になるから右辺は
         - balance1 > reserve1 - amount1Out ? balance1 - reserve1 : 0; で良いが便宜上 "= amount1Out" をたしてる。
        */
        
        //定数積公式(手数料 0.3% 想定)
        uint balance0Adjusted = (balance0 * 1000) - (amount0In * 3); //(※3)
        uint balance1Adjusted = (balance1 * 1000) - (amount1In * 3); //(※4)
        require(balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * 1000**2, 'uniswapV2StyleDexPool: K'); //(※5)
        /*
         - (※3,4) reserve0 + amount0In * 0.997 を　balance0 - amount0In * 0.003 にしてる。前もって99.7%掛けるんではなく後から0.3%引いてる。
         - さらに、各項に1000掛けて小数を消してる。
         - (※5) 定数積公式なので両辺 "="　のはずが　">=" になる理由だが、まずuniswapV2StyleDexRouterコントラクトのswapTokenPair関数で求めた
         - amountOutはsolidityの事情で小数を切り捨てた値なので、reserveから出ていく量が小数ぶん減り、プールに残る量が小数ぶん増える。よって、
         - そのまま計算された左辺の値は想定より大きくなってしまう。
         -
         -
         - ・スワップ手数料によって流動性提供者が得をする仕組み
         - 定数積公式はプールに入ってくるInの量から手数料を差し引いた状態で計算されるが、実際にプールに入ってくるのは手数料を差し引いてないIn
         - の量である。よって流動性提供者が増えたりしたわけでもないのに、スワップのたびに投入した方のトークンのプール内の量が手数料分増える。
         - これは、定数積公式の K が前回の K より僅かに増えるということでもある。この仕組みは流動性提供者のためのものである。というのも、流動
         - 性提供者からすれば提供していたトークンペアを返してもらう際、世界中の流動性提供者が持っている流動性トークンの総量に対する自分が持って
         - いる流動性トークンの量と同じ割合でプールにあるトークンの量から自分の手元に帰ってくるトークンの量が決まるわけだが、分母であるプール内
         - のトークン量が勝手に増えてくれるおかげで引っぱり出せるトークンの量が増えるのだ。例えば流動性トークンを全体の1割持っていてプール内の
         - トークンMの量が50、トークンNの量が100だとしたら、流動性トークンを返せばトークンMとNそれぞれ5と10返ってくる。ただもし誰かのスワップ
         - のおかげでプール内のトークンMの量が60、トークンNの量が110とかになっていたなら、返ってくるトークンMとNはそれぞれ6と11に増える、自分
         - は特に何もしていないのにだ。この仕組みのおかげで流動性提供者が増える。
        */

        reserve0 = balance0;
        reserve1 = balance1;
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
}