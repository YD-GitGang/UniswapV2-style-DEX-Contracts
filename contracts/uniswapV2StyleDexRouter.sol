//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import './libraries/uniswapV2StyleDexLibrary.sol';
import './interfaces/IERC20.sol';
import './uniswapV2StyleDexPool.sol';
import './uniswapV2StyleDexFactory.sol';

contract uniswapV2StyleDexRouter {
    address public immutable factory; 

    constructor(address _factory) {
        factory = _factory;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'uniswapV2StyleDexRouter: EXPIRED');
        _;
    }

    function _addLiquidity(
        address pool,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal view returns (uint amountA, uint amountB) {
        uint reserve0 = uniswapV2StyleDexPool(pool).reserve0();
        uint reserve1 = uniswapV2StyleDexPool(pool).reserve1();
        (uint reserveA, uint reserveB) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = uniswapV2StyleDexLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) { //(※3)
                require(amountBOptimal >= amountBMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = uniswapV2StyleDexLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired); //(※4)
                require(amountAOptimal >= amountAMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
            /*
             - ・ _addLiquidityのイメージ。流動性提供者がUI画面で一方のトークンの希望提供量を入力。するとその瞬間のトークン比
             - からもう片方のトークンの想定提供量が計算される。提供量がこの時点であくまで希望や想定なのは流動性提供者が
             - UIを操作し確定ボタンを押し関数が実行されるまでのわずかな間も世界の誰かがこのプールでスワップをしプールのトークン
             - 比が変動しているため、希望とは若干違う提供量になるからだ。関数が実行され実際の提供量を計算する際、流動性提供者が
             - UI画面で確認した希望(想定)提供量を最大量としどちらのトークンもそれ以下の提供量になるように再計算される。流動性
             - 提供者からすれば、想定より少なくなる分には構わないが想定を上回り足りない分を勝手に自分のウォレットから抜き取られるのは
             - 迷惑な話というわけだ。(例) 現在のプール内のトークン比はトークンXの方がトークンYより少し多い程度と仮定。UI画面で
             - トークンXの希望提供量を入力するとその瞬間のトークン比から計算されたトークンYの提供量がUI画面に映し出される。その
             - 提供量に納得し確定ボタンを押して関数が実行されるが誰かのスワップによりプール内のトークン比はトークンYの方がトークン
             - Xより少し多くなっていて実際の提供量が変動。希望したトークンXの量を提供するにはトークンYの提供量がUIで確認した時
             - の量よりもさらに必要になる。しかしそのさらに必要になったトークンYを流動性提供者のウォレットから勝手に抜き取るわ
             - けにはいかない。そこで、UIで確認したトークンYの量を提供するとしてトークンXの提供量を新たに再計算する。すると、
             - トークンXの提供量は希望量より減りトークンYは希望通りの提供量という結果になる。
             -
             - ・ 誰もpoolのトークンをswapせずDesired通りにpoolに預け入れることが出来たら,
             - (※3)側でも(※4)側でもどっちでも問題ないから(※3)と(※4)の条件式の
             - 両方ともに = があってもokってことだろうか? (※4)の =　なくてもいいような。
             */
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity){
        address pool = uniswapV2StyleDexFactory(factory).getPool(tokenA, tokenB);
        if (pool == address(0)) {
            uniswapV2StyleDexFactory(factory).createPool(tokenA, tokenB); //(※1)
            pool = uniswapV2StyleDexFactory(factory).getPool(tokenA, tokenB); //(※2)
            //(※1)の戻り値poolだから(※2)書かずに、(※1)を pool = uniswapV2StyleDexFactory(factory).createPool(tokenA, tokenB) としてもOK。
        }
        (amountA, amountB) = _addLiquidity(pool, tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        bool successA = IERC20(tokenA).transferFrom(msg.sender, pool, amountA);
        require(successA, 'uniswapV2StyleDexRouter: TOKEN_A_TRANSFER_FAILED');
        bool successB = IERC20(tokenB).transferFrom(msg.sender, pool, amountB);
        require(successB, 'uniswapV2StyleDexRouter: TOKEN_B_TRANSFER_FAILED');

        liquidity = uniswapV2StyleDexPool(pool).mint(to);
    }

    function removeLiquidity (
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns(uint amountA, uint amountB) {
        address pool = uniswapV2StyleDexFactory(factory).getPool(tokenA, tokenB);
        require(pool != address(0), 'uniswapV2StyleDexRouter: POOL_DOES_NOT_EXIST');

        uniswapV2StyleDexPool(pool).transferFrom(msg.sender, pool, liquidity);
        (uint amount0, uint amount1) = uniswapV2StyleDexPool(pool).burn(to);
        
        (amountA, amountB) = tokenA < tokenB ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_B_AMOUNT');
    }
    
    function swapTokenPair (
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns(uint amountOut) {
        address pool = uniswapV2StyleDexFactory(factory).getPool(tokenIn, tokenOut);
        require(pool != address(0), 'uniswapV2StyleDexRouter: POOL_DOES_NOT_EXIST');

        {  // Avoid stack too deep error
        uint reserve0 = uniswapV2StyleDexPool(pool).reserve0();
        uint reserve1 = uniswapV2StyleDexPool(pool).reserve1();
        (uint reserveIn, uint reserveOut) = tokenIn < tokenOut ? (reserve0, reserve1) : (reserve1, reserve0);
        amountOut = uniswapV2StyleDexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        }

        require(amountOut >= amountOutMin, 'uniswapV2StyleDexRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        //bool success = uniswapV2StyleDexERC20(tokenIn).transferFrom(msg.sender, pool, amountIn);
        bool success = IERC20(tokenIn).transferFrom(msg.sender, pool, amountIn);
        require(success, 'uniswapV2StyleDexRouter: TOKEN_IN_TRANSFER_FAILED');
        (uint amount0Out, uint amount1Out) = tokenIn < tokenOut ? (uint(0), amountOut) : (amountOut, uint(0));  // (※1)
        uniswapV2StyleDexPool(pool).swap(amount0Out, amount1Out, to);
        /*
         - (※1) uint(0): 0が256bitの符号なし整数であることを明示。でないとuint8と判断される。
         - エラー参考: True expression's type tuple(uint8,uint256) does not match false expression's type tuple(uint256,uint8).
        */
    }

    function getAmountOut (uint amountIn, uint reserveIn, uint reserveOut) external pure returns(uint amountOut) {
        amountOut = uniswapV2StyleDexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /*
     ----------定数積公式memo----------
     -
     - (Xa+Da)  *  (Xb-Db) = Xa  *  Xb
     -                  Db = Da  *  Xb/Xa  *  1/(1+Da/Xa) ...(1)
     -　　　　　　　　　　　   1項　　  2項　　　    3項
     - 
     - 
     - Xa:トークンaのプールの量
     - Xb:トークンbのプールの量
     - Da:トークンaのプールに新たに入れるトークンaの量
     - Db:トークンbのプールから取り出せるトークンbの量
     - 
     - 第2項:価格(分母を1としたときの分子のパワー)
     - 第3項:引き出そうとすればするほど引き出せなくする。通常1よりほんの少し小さい値。
     - 
     - 
     - 
     - 
     - ・価格の安定。価格はプール比。引き出そうとすればするほど引き出せなくなる。ちょこっとだけ引き出すと得する。
     - 定数積公式(1)の第3項の分母XaがDaに対しものすごく大きいと第3項全体の変化が少なくて第2項(価格...※2)への影響が小さく価格が安定するが、逆にXaが少
     - ないと第2項(価格)への影響が大きく価格の変動が激しい。入れる量に比べてプールにある量が圧倒的に多いと、第2項(価格)への影響力は低い。引き出そうと
     - すればするほど(入れれば入れるほど)入れた量がプール内の量に近づき第3項の分母が大きくなって第3項全体が小さくなるので、第2項(価格)に及ぼす影響力が
     - 増して引き出せる量が減る。プールの量が多ければ多い程引き出せなくする度合いが下がる。
     - 
     - 
     - 
     - 
     - ・DEXの価格(プールのトークン比)は外の世界の価格になろうとする。スワップするモチベーション。
     - スワップのモチベは外の世界と比較して安く手に入るのか否かだ。外の世界と比べてこのDEXの世界は安いから欲しい、高いからいらない。
     - 価格はプール比(第2項)だが、突っ込む前のプール比は「その瞬間の価格」であって価格通りには買えない。突っ込み始めたとたんから価格は上がり、引き出そ
     - うとすればするほど価格は上がる。実際の価格は 1)突っ込んだ量と引き出せた量の比、もしくわ 2)突っ込んだ後のプール比から求まる。
     - 
     - (例)
     - ドル:10000000, 円:10000000000　のプール
     - 
     - 1)突っ込んだ量と引き出せた量の比
     - 10000000ドル突っ込んで5000000000円引き出せた。
     - 価格(分母を1としたときの分子のパワー)は5000000000円/10000000ドル。500円を1ドルでゲット出来たことになる。
     - 
     - 2)突っ込んだ後のプール比
     - 突っ込む前が10000000000円/10000000ドルでそこに10000000突っ込んだら10000000000円/20000000ドルになる。
     - 10000000000円/10000000ドルは「その瞬間の価格(分母を1としたときの分子のパワー)」。
     - 実際の価格(分母を1としたときの分子のパワー)は10000000000円/20000000ドル。500円を1ドルでゲット出来たことになる。
     - 
     - 引き出せた量 / 突っ込んだ量 = Xb / Xa+Da = 実際の価格　(突っ込んだ量と引き出せた量の比 = 突っ込んだ後のプール比 = 実際の価格)
     - 
     - DEX内の価格が外の世界の価格とズレることがスワップのモチベになる。
     - 
     - 
     - 
     - 
     - ・1発で100投入しようが、2発にわけて50と50で投入しようが、引き出せる量は一緒。
     - 1発で100投入すると第3項のDaがXaに近づく具合が大きくて第3項の分母が大きくなって第3項全体が小さくなる。一方2発に分けた方では、第3項のDaは2発とも
     - Xaに近づく具合が小さく第3項の分母が小さくなって第3項全体は大きくなるが、1発で投入するときより第1項が小さい上、2発目の計算の第2項が小さくなるの
     - で帳尻が合う。
     - 
     - 
     - 
     - 
     - ・無下限呪術。全部は引き出せない。
     - Xb全てを引き出そうとDaを増やしていくとする。投入額DaがXaをこえてからは定数積公式は下の式に落ち着く。
     - 
     - Db = Xb * Q * 1/(Q+1)...(投入額が大きければ大きい程Qは大きくなる)
     - 
     - Xb以外の分子より分母は1大きくなるので、投入額を増やしQを大きくしてもXb以外を表す部分は0.99999〜のようにだんだん1に近づきはするが永遠に1になる
     - 事はない。よってXb × 0.9999…99となりXbを限りなく全て引き出せるものの全部は引き出せない。
     - とはいっても物凄い損をするのでこれをするモチベーションはないだろう。
     - (例)
     - ドル:10000000, 円:10000000000　のプール
     - 100億ドル     入れて 9990009990.00999円 引き出せた。
     - 5兆800億ドル  入れて 9999980314.99938円 引き出せた。
     - 
    */
}