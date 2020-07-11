---
title: markdown设置sublime默认打开
date: 2020-04-09
categories:
    - other
tags:
    - other
---


### 设置markdown的默认打开工具

	- win+R组合键打开运行对话框,输入regedit,打开注册表编辑器
	- 定位到计算机HKEY_CLASSES_ROOT项
	- HKEY_CLASSES_ROOT 右击，选择 新建-项,命名为 .md
	- 选中.md(这个项),双击右边的默认项，打开编辑字符串对话框,写 md_auto_file 确定退出
		(格式：后缀名_auto_file，后缀名即为你要关联的文件类型，如要关联.html，就填写 html_auto_file)
	- 再次对着HKEY_CLASSES_ROOT项单右击,新建项,命名为 md_auto_file
	- 选中md_auto_file，新建-项 设置项名为: HKEY_CLASSES_ROOTmd_auto_fileshellopencommand, 设置右边默认值为:"sublime安装路径 %1",
		例如:  "D:\sublime\Sublime Text 3\sublime_text.exe" %1 [注意添加英文状态下的双引号及后面的 %1与前面有空格]
	- 定位到HKEY_CURRENT_USER/Software/classes，重复以上的步骤创建 .md, md_auto_file项并设值
	- 退出注册表编辑器,此时md文件已经关联到sublime，右键点击md文件你会发现右键菜单第一项变成了"打开"