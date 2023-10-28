<style type="text/css">
.tg  {border-collapse:collapse;border-spacing:0;}
.tg td{border-color:black;border-style:solid;border-width:1px;font-family:Arial, sans-serif;font-size:14px;
  overflow:hidden;padding:10px 5px;word-break:normal;}
.tg th{border-color:black;border-style:solid;border-width:1px;font-family:Arial, sans-serif;font-size:14px;
  font-weight:normal;overflow:hidden;padding:10px 5px;word-break:normal;}
.tg .tg-9wq8{border-color:inherit;text-align:center;vertical-align:middle}
.tg .tg-wa1i{border-color:inherit;font-weight:bold;text-align:center;vertical-align:middle}
.tg .tg-nrix{border-color:inherit;text-align:center;vertical-align:middle}
.tg .tg-uzvj{border-color:inherit;font-weight:bold;text-align:center;vertical-align:middle}
</style>
<table class="tg">
<thead>
  <tr>
    <th class="tg-9wq8">寄存器名称</th>
    <th class="tg-9wq8">功能描述</th>
    <th class="tg-9wq8">字段名称</th>
    <th class="tg-9wq8">字段</th>
    <th class="tg-9wq8">读写权限</th>
    <th class="tg-nrix">功能描述</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td class="tg-uzvj" rowspan="8"><span style="font-weight:bold">CRMD</span></td>
    <td class="tg-9wq8" rowspan="8">当前模式信息</td>
    <td class="tg-9wq8">PLV</td>
    <td class="tg-9wq8">1:0</td>
    <td class="tg-9wq8">RW</td>
    <td class="tg-nrix">当前特权等级，其合法的取值为0~3。0表示最高特权等级，3表示最低特权等级。</td>
  </tr>
  <tr>
    <td class="tg-nrix">IE</td>
    <td class="tg-nrix">2</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">当前全局中断使能，高有效。</td>
  </tr>
  <tr>
    <td class="tg-nrix">DA</td>
    <td class="tg-nrix">3</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">直接地址翻译模式的使能，高有效。</td>
  </tr>
  <tr>
    <td class="tg-nrix">PG</td>
    <td class="tg-nrix">4</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">映射地址翻译模式的使能，高有效。</td>
  </tr>
  <tr>
    <td class="tg-nrix">DATF</td>
    <td class="tg-nrix">6:5</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">直接地址翻译模式时，取值操作的存储访问类型。</td>
  </tr>
  <tr>
    <td class="tg-nrix">DATM</td>
    <td class="tg-nrix">8:7</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">直接地址翻译模式时，load和store操作的存储访问类型。</td>
  </tr>
  <tr>
    <td class="tg-nrix">WE</td>
    <td class="tg-nrix">9</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">指令和数据监视点的使能位，高有效。</td>
  </tr>
  <tr>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">31:10</td>
    <td class="tg-nrix">R0</td>
    <td class="tg-nrix">保留域，读返回0，且软件不允许改变其值。</td>
  </tr>
  <tr>
    <td class="tg-uzvj" rowspan="4">PRMD</td>
    <td class="tg-9wq8" rowspan="4">例外前模式信息</td>
    <td class="tg-9wq8">PPLV</td>
    <td class="tg-9wq8">1:0</td>
    <td class="tg-9wq8">RW</td>
    <td class="tg-nrix">保存、恢复例外触发前的特权等级（TLB重填和机器错误除外）</td>
  </tr>
  <tr>
    <td class="tg-nrix">PIE</td>
    <td class="tg-nrix">2</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">保存、恢复例外触发前的全局中断使能（TLB重填和机器错误除外）</td>
  </tr>
  <tr>
    <td class="tg-nrix">PWE</td>
    <td class="tg-nrix">3</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">保存、恢复例外触发前的指令和监视点使能（TLB重填和机器错误除外）</td>
  </tr>
  <tr>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">31:4</td>
    <td class="tg-nrix">R0</td>
    <td class="tg-nrix">保留域，读返回0，且软件不允许修改其值。</td>
  </tr>
  <tr>
    <td class="tg-uzvj" rowspan="4">ECFG</td>
    <td class="tg-9wq8" rowspan="4">例外配置</td>
    <td class="tg-9wq8">LIE</td>
    <td class="tg-9wq8">12:0</td>
    <td class="tg-9wq8">RW</td>
    <td class="tg-nrix">局部中断使能位，高有效。这13位与13种中断源一一对应，每一位控制一种中断的使能。</td>
  </tr>
  <tr>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">15:13</td>
    <td class="tg-nrix">R0</td>
    <td class="tg-nrix">保留域，读返回0，且软件不允许修改其值。</td>
  </tr>
  <tr>
    <td class="tg-nrix">VS</td>
    <td class="tg-nrix">18:16</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">配置例外和中断入口的距离。当VS=0时，所有例外和中断的地址是同一个。当VS!=0时，各例外和中断入口之间的间距是2^vs条指令。</td>
  </tr>
  <tr>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">31:19</td>
    <td class="tg-nrix">R0</td>
    <td class="tg-nrix">保留域，读返回0，且软件不允许修改其值。</td>
  </tr>
  <tr>
    <td class="tg-uzvj" rowspan="9">ESTAT</td>
    <td class="tg-9wq8" rowspan="9">例外状态</td>
    <td class="tg-9wq8">IS[1:0]</td>
    <td class="tg-9wq8">1:0</td>
    <td class="tg-9wq8">RW</td>
    <td class="tg-nrix">2个软件中断源的状态位，对应SWI1和SWI0。</td>
  </tr>
  <tr>
    <td class="tg-nrix">IS[9:2]</td>
    <td class="tg-nrix">9:2</td>
    <td class="tg-nrix">R</td>
    <td class="tg-nrix">8各硬件中断源的状态位，对应HWI7~HWI0。软件只可读不可写。</td>
  </tr>
  <tr>
    <td class="tg-nrix">IS[10]</td>
    <td class="tg-nrix">10</td>
    <td class="tg-nrix">R</td>
    <td class="tg-nrix">性能计数器溢出中断（PMI）的状态位。软件只可读不可写。</td>
  </tr>
  <tr>
    <td class="tg-nrix">IS[11]</td>
    <td class="tg-nrix">11</td>
    <td class="tg-nrix">R</td>
    <td class="tg-nrix">定时器中断（TI）的状态位。软件只可读不可写。</td>
  </tr>
  <tr>
    <td class="tg-nrix">IS[12]</td>
    <td class="tg-nrix">12</td>
    <td class="tg-nrix">R</td>
    <td class="tg-nrix">核间中断（IPI）的状态位。软件只可读不可写。</td>
  </tr>
  <tr>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">15:13</td>
    <td class="tg-nrix">R0</td>
    <td class="tg-nrix">保留域，读返回0，且软件不允许修改其值。</td>
  </tr>
  <tr>
    <td class="tg-nrix">Ecode</td>
    <td class="tg-nrix">21:16</td>
    <td class="tg-nrix">R</td>
    <td class="tg-nrix">例外类型一级编码。</td>
  </tr>
  <tr>
    <td class="tg-nrix">EsubCode</td>
    <td class="tg-nrix">30:22</td>
    <td class="tg-nrix">R</td>
    <td class="tg-nrix">例外类型二级编码。</td>
  </tr>
  <tr>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">31</td>
    <td class="tg-nrix">R0</td>
    <td class="tg-nrix">保留域，读返回0，且软件不允许修改其值。</td>
  </tr>
  <tr>
    <td class="tg-uzvj">ERA</td>
    <td class="tg-9wq8">例外返回地址</td>
    <td class="tg-9wq8">PC</td>
    <td class="tg-9wq8">31:0</td>
    <td class="tg-9wq8">RW</td>
    <td class="tg-nrix">记录例外触发指令的PC（TLB重填和机器错误除外）</td>
  </tr>
  <tr>
    <td class="tg-uzvj">BADV</td>
    <td class="tg-9wq8">出错虚地址</td>
    <td class="tg-9wq8">VAddr</td>
    <td class="tg-9wq8">31:0</td>
    <td class="tg-9wq8">RW</td>
    <td class="tg-nrix">当触发地址错误相关例外时，记录出错的虚地址。包括取指地址出错（此时应该记录出错的PC），load/store操作地址出错，地址对齐出错等等。</td>
  </tr>
  <tr>
    <td class="tg-uzvj" rowspan="2">EENTRY</td>
    <td class="tg-9wq8" rowspan="2">例外入口地址</td>
    <td class="tg-9wq8">0</td>
    <td class="tg-9wq8">11:0</td>
    <td class="tg-9wq8">R0</td>
    <td class="tg-nrix">只读恒为0，写被忽略。</td>
  </tr>
  <tr>
    <td class="tg-nrix">VPN</td>
    <td class="tg-nrix">31:12</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">普通例外和中断入口地址所在页的页号。</td>
  </tr>
  <tr>
    <td class="tg-wa1i">SAVE(0~3)</td>
    <td class="tg-nrix">数据保存</td>
    <td class="tg-nrix">Data</td>
    <td class="tg-nrix">31:0</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">特权态软件临时存放的数据。除执行CSR指令外硬件不会修改该域的内容。</td>
  </tr>
  <tr>
    <td class="tg-wa1i">TID</td>
    <td class="tg-nrix">定时器编号</td>
    <td class="tg-nrix">TID</td>
    <td class="tg-nrix">31:0</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">定时器编号。软件可配置。处理器核复位期间，硬件可以将其复位成与CSR.CPUID中CoreID相同的值。</td>
  </tr>
  <tr>
    <td class="tg-wa1i" rowspan="4">TCFG</td>
    <td class="tg-nrix" rowspan="4">定时器配置</td>
    <td class="tg-nrix">En</td>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">定时器使能位。</td>
  </tr>
  <tr>
    <td class="tg-nrix">Periodic</td>
    <td class="tg-nrix">1</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">定时器循环模式控制位。有2种定时模式。</td>
  </tr>
  <tr>
    <td class="tg-nrix">InitVal</td>
    <td class="tg-nrix">n-1:2</td>
    <td class="tg-nrix">RW</td>
    <td class="tg-nrix">定时器倒计时自减计数的初始值。要求该初始值必须是4的整数倍，硬件将自动在该域数值的最低位补上2位0后再使用。</td>
  </tr>
  <tr>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">31:n</td>
    <td class="tg-nrix">R0</td>
    <td class="tg-nrix">只读恒为0，写被忽略。</td>
  </tr>
  <tr>
    <td class="tg-wa1i" rowspan="2">TVAL</td>
    <td class="tg-nrix" rowspan="2">定时器值</td>
    <td class="tg-nrix">TimeVal</td>
    <td class="tg-nrix">n-1:0</td>
    <td class="tg-nrix">R</td>
    <td class="tg-nrix">当前定时器的计数值。</td>
  </tr>
  <tr>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">31:n</td>
    <td class="tg-nrix">R0</td>
    <td class="tg-nrix">只读恒为0，写被忽略。</td>
  </tr>
  <tr>
    <td class="tg-wa1i" rowspan="2">TICLR</td>
    <td class="tg-nrix" rowspan="2">定时中断清除</td>
    <td class="tg-nrix">CLR</td>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">W1</td>
    <td class="tg-nrix">当对该位写1时，将清除时钟中断标记。且该位读出结果总为0.</td>
  </tr>
  <tr>
    <td class="tg-nrix">0</td>
    <td class="tg-nrix">31:1</td>
    <td class="tg-nrix">R0</td>
    <td class="tg-nrix">保留域，读返回0，且软件不允许修改其值。</td>
  </tr>
</tbody>
</table>