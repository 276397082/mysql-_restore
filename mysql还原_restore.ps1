        # 定义连接字符串
        $username = "root"
        $password = "123456"
        $database = "test"
        $server = "127.0.0.1"




# 加载所需的程序集
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

    # MySQL连接配置
    # 导入 .NET Framework 中的类库
    # 确保MySQL Connector/NET已经安装
    # 如果是手动下载的DLL，可以指定路径加载，例如:
    $mysqlAssemblyPath = "MySql.Data.dll"
    [System.Reflection.Assembly]::LoadFrom($mysqlAssemblyPath) | Out-Null

# 弹出文件选择窗口让用户选择全备sql文件
$fileDialog = New-Object System.Windows.Forms.OpenFileDialog
$fileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
$fileDialog.Filter = "SQL files (*.sql)|*.sql"
$fileDialog.Multiselect = $false

if ($fileDialog.ShowDialog() -eq 'OK') {
    $sqlScriptPath = $fileDialog.FileName
    $sqlPath=$fileDialog.InitialDirectory
    # 读取backfull.sql文件
    $sqlScript = Get-Content -Path $sqlScriptPath -Raw  -Encoding UTF8
}
else {
    Write-Host "用户取消了选择。"
    exit
}


##生成列表
function tables_list($sqlf,$tableName){
    
    # 使用正则表达式提取所有表名
    $tablePattern = 'CREATE TABLE `(\w+)`'
    $tableMatches = [regex]::Matches($sqlf, $tablePattern)
    if ($tableName){
        $tableMatches=$tableName
    }
    # 列出所包含的表，并让用户勾选需要提取的表
    $checkedTables = @()
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "选择要提取的表"
    $form.Size = New-Object System.Drawing.Size(300,800)
    $form.StartPosition = "CenterScreen"
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Location = New-Object System.Drawing.Point(10,10)
    $checkedListBox.Size = New-Object System.Drawing.Size(260,700)
    

    # 添加 SelectedIndexChanged 事件处理程序
    $checkedListBox.add_SelectedIndexChanged({
        param($sender, $e)
        $selectedIndex = $checkedListBox.SelectedIndex
        if ($selectedIndex -ne -1) {
            # 切换选中状态
            $checkedListBox.SetItemChecked($selectedIndex, -not $checkedListBox.GetItemChecked($selectedIndex))
            $checkedListBox.ClearSelected() # 清除选中状态，防止重复触发事件
        }
        # 检查是否至少有一个表被选中，如果是则启用确定按钮，否则禁用
        if ($checkedListBox.CheckedItems.Count -gt 0) {
            $okButton.Enabled = $true
        } else {
            $okButton.Enabled = $false
        }
    })

    # 检查是否匹配到了表，如果没有，给出提示并退出
    #if ($tableMatches.Count -eq 0) {
    #    Write-Host "未找到任何表定义。请确保 SQL 文件包含有效的 CREATE TABLE 语句。"
    #    exit
    #}
    foreach ($match in $tableMatches) {
        if ($match.Groups.Count -gt 0) {
            $tableName = $match.Groups[1].Value
        }else{
             $tableName =$match
        }
        
        $checkedListBox.Items.Add($tableName) | Out-Null
    }


    $form.Controls.Add($checkedListBox)
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75,720)
    $okButton.Size = New-Object System.Drawing.Size(75,23)
    $okButton.Text = "确定"
    $okButton.Enabled = $false # 初始状态下禁用确定按钮
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(160,720)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = "取消"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)
    $form.TopMost = $true

        #$form.Add_Shown({
        ## 在窗体显示时检查是否至少有一个表被选中
        #    if ($checkedListBox.CheckedItems.Count -eq 0) {
        #        [System.Windows.Forms.MessageBox]::Show("请至少选择一个表格。", "警告", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        #    }
        #})

    $result = $form.ShowDialog()
    # 将多个值存储在数组中
    $values = @($result,$checkedListBox)
    RETURN  $values

} 



    ##提取表数据及结构
    $tals=tables_list $sqlScript
    
    if ($tals[0] -ne [System.Windows.Forms.DialogResult]::OK ) {
         Write-Host "用户取消了操作1。"
        exit
    }
    #if ($tals[1].CheckedItems.Count -cle 0){
    #    [System.Windows.Forms.MessageBox]::Show("请至少选择一个表格。", "警告", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    #
    #}





 ## 生成表数据及结果sql文件
function GetDatatable($sqlf,$tables){

$savePaht=$sqlPath  +"\Mysql_file\"


# 检查文件夹是否存在
if (Test-Path $savePaht -PathType Container) {
    # 如果文件夹存在，则清空文件夹内的内容
    Remove-Item -Path "$savePaht\*" -Force -Recurse
    Write-Host "文件夹已清空：$savePaht"
} else {
    # 创建文件夹
    New-Item -Path $savePaht -ItemType Directory -Force | Out-Null
    Write-Host "文件夹已创建：$savePaht"
}




 # 对每个选中的表执行还原
        foreach ($tableName in $tables) {
            $a=$savePaht + "$tableName.sql"
            # $tableSqlPattern = "CREATE TABLE ``$tableName`` \((.*?)\);"
            $tableSqlPattern = "DROP TABLE IF EXISTS ``$tableName``;(.*?)TABLES;"
            $tableSqlMatch = [regex]::Match($sqlf, $tableSqlPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($tableSqlMatch.Success) {
                $tableSql = $tableSqlMatch.Value

                # 将表的结构和数据保存到独立的文件
                $tableSql | Out-File -FilePath "$a"
            }
        }

}

 ## 生成表数据及结果sql文件
GetDatatable $sqlScript $tals[1].CheckedItems

##还原列表选择
$talsb=tables_list $sqlScript $tals[1].CheckedItems
 if ($talsb[0] -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "用户取消了操作2。"
    exit
 }

##执行还原操作
function hy($Tableslist){
$savePaht=$sqlPath  +"\Mysql_file\"


    # 连接到MySQL数据库
    try {
         # 构建连接字符串
         $connectionString = "Server=$server;Database=$database;User Id=$username;Password=$password;"
         
         # 创建并打开数据库连接
         $connection = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionString)
         $connection.Open()
         if ($connection.State -ne [System.Data.ConnectionState]'Open') {
            Write-Host "无法连接到数据库，请检查连接参数。"
            exit
         }
        # 对每个选中的表执行还原
        foreach ($tableName in $Tableslist) {

                $a=$savePaht + "$tableName.sql"
                # 将表的结构和数据保存到独立的文件
               
                $tableSql = Get-Content -Path $a -Raw  -Encoding UTF8
                   
                $query = "SELECT * FROM assets LIMIT 10;"
                $command = New-Object MySql.Data.MySqlClient.MySqlCommand($tableSql, $connection)
                # 执行SQL脚本
                $OKis=$command.ExecuteNonQuery() #| Out-Null
                #$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command)
                #$dataTable = New-Object System.Data.DataTable
                #$dataAdapter.Fill($dataTable)

                Write-Host "表 $tableName 已成功还原到 $database 数据库中总共 $OKis 行数据"
                    
                 # 显示查询结果
                 #$dataTable | Format-Table
                 
                 
           
            
            
        }
        # 关闭连接
        $connection.Close()
    }
    catch {
        Write-Host "MySQL错误: $_"
    }
    finally {
        if ($connection.State -eq 'Open') {
            $connection.Close()
        }
    }
}

foreach ($item in $talsb[1].CheckedItems) {
             
            # 执行还原时再次提醒用户勾选并确认是否要还原对应的表
            $confirmMessage = "你选择了以下表进行还原:`n$($item -join ', ')`n`n你确定要继续吗？"
            $confirmResult = [System.Windows.Forms.MessageBox]::Show($confirmMessage, "确认还原", "YesNo", "Warning")
            

            if ($confirmResult -eq "Yes"){
            
                             
                hy $item
            }
            
    }

    pause