# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$adbPath = "C:\Users\Borek\Documents\platform-tools\adb.exe"

# Create a new form
$form = New-Object System.Windows.Forms.Form
$form.Text = "The wonderful UNENSHITTIFIER for your elderly Android tablet or phone"
$form.Size = New-Object System.Drawing.Size(1000, 600)
$form.StartPosition = "CenterScreen"
$form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized

# Create a TableLayoutPanel to organize the form layout
$tableLayoutPanel = New-Object System.Windows.Forms.TableLayoutPanel
$tableLayoutPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$tableLayoutPanel.ColumnCount = 2
$tableLayoutPanel.RowCount = 2
$tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))
$tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
$tableLayoutPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$tableLayoutPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$form.Controls.Add($tableLayoutPanel)

# Create a TextBox for filtering
$filterTextBox = New-Object System.Windows.Forms.TextBox
$filterTextBox.Dock = [System.Windows.Forms.DockStyle]::Top
$filterTextBox.Font = New-Object System.Drawing.Font("Arial", 12)
$filterTextBox.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        Filter-Packages
        $_.SuppressKeyPress = $true
    }
    elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::A -and $_.Control) {
        $filterTextBox.SelectAll()
        $_.SuppressKeyPress = $true
    }
})
$tableLayoutPanel.Controls.Add($filterTextBox, 0, 0)
$tableLayoutPanel.SetColumnSpan($filterTextBox, 2)

# Create a FlowLayoutPanel to hold the checkboxes
$flowLayoutPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$flowLayoutPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$flowLayoutPanel.AutoScroll = $true
$flowLayoutPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$flowLayoutPanel.WrapContents = $false
$tableLayoutPanel.Controls.Add($flowLayoutPanel, 0, 1)

# Create a log pane on the right
$logTextBox = New-Object System.Windows.Forms.TextBox
$logTextBox.Multiline = $true
$logTextBox.ScrollBars = "Vertical"
$logTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$logTextBox.Font = New-Object System.Drawing.Font("Arial", 10)
$logTextBox.ReadOnly = $true
$tableLayoutPanel.Controls.Add($logTextBox, 1, 1)

# Function to get all packages (installed and uninstalled) from connected Android device
function Get-AllAndroidPackages {
    $installedPackages = & $adbPath shell pm list packages | ForEach-Object { $_.Split(":")[1] }
    $allPackages = & $adbPath shell pm list packages -u | ForEach-Object { $_.Split(":")[1] }
    $packageStatus = @{}
    foreach ($package in $allPackages) {
        if ($package -ne "android") {
            $packageStatus[$package] = $installedPackages -contains $package
        }
    }
    return $packageStatus
}

# Function to handle checkbox click
function Handle-CheckboxClick($packageName, $isChecked) {
    if ($isChecked) {
        # Install the package
        $result = & $adbPath shell cmd package install-existing $packageName 2>&1
        if ($result -match "Success" -or $result -match "Package .+ installed for user: \d+") {
            Log-Message "Installed: $packageName"
        } else {
            Log-Message "Failed install: $packageName. Error: $result"
        }
    } else {
        # Uninstall the package
        $result = & $adbPath shell pm uninstall --user 0 $packageName 2>&1
        if ($result -match "Success") {
            Log-Message "Uninstalled: $packageName"
        } else {
            Log-Message "Failed uninstall: $packageName. Error: $result"
        }
    }
}

# Function to filter packages based on text input
function Filter-Packages {
    $filterText = $filterTextBox.Text.ToLower()
    $flowLayoutPanel.SuspendLayout()
    $flowLayoutPanel.Visible = $false
    foreach ($control in $flowLayoutPanel.Controls) {
        if ($control -is [System.Windows.Forms.Panel]) {
            $checkbox = $control.Controls[0]
            $label = $control.Controls[1]
            if ($label.Text.ToLower().Contains($filterText)) {
                $control.Visible = $true
            } else {
                $control.Visible = $false
            }
        }
    }
    $flowLayoutPanel.ResumeLayout()
    $flowLayoutPanel.Visible = $true
}

# Function to log messages to the log pane
function Log-Message($message) {
    $logTextBox.AppendText("$message`r`n")
    $logTextBox.ScrollToCaret()
}

# Function to open Google search for package name
function Open-GoogleSearch($packageName) {
    $searchUrl = "https://www.google.com/search?q=what+is+android+package+`"`"$packageName`"`""
    Start-Process $searchUrl
    Log-Message "Clicked: $packageName"
}

# Get the list of all packages and their installation status
$packages = Get-AllAndroidPackages

# Check if packages were retrieved successfully
if ($packages.Count -eq 0) {
    $errorLabel = New-Object System.Windows.Forms.Label
    $errorLabel.Text = "Error: No packages found. Make sure ADB is properly connected."
    $errorLabel.AutoSize = $true
    $errorLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $flowLayoutPanel.Controls.Add($errorLabel)
    Log-Message "Error: No packages found. Make sure ADB is properly connected."
} else {
    # Create checkboxes and labels for each package
    foreach ($package in $packages.Keys | Sort-Object) {
        $panel = New-Object System.Windows.Forms.Panel
        $panel.AutoSize = $true
        $panel.Dock = [System.Windows.Forms.DockStyle]::Top

        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.AutoSize = $true
        $checkbox.Location = New-Object System.Drawing.Point(0, 0)
        $checkbox.Checked = $packages[$package]  # Set checkbox state based on installation status
        $checkbox.Add_Click({ Handle-CheckboxClick $this.Parent.Controls[1].Text $this.Checked })

        $label = New-Object System.Windows.Forms.Label
        $label.Text = $package
        $label.AutoSize = $true
        $label.Location = New-Object System.Drawing.Point(20, 0)
        $label.Font = New-Object System.Drawing.Font("Arial", 10)
        $label.Cursor = [System.Windows.Forms.Cursors]::Hand
        $label.Add_Click({ Open-GoogleSearch $this.Text })

        $panel.Controls.Add($checkbox)
        $panel.Controls.Add($label)
        $flowLayoutPanel.Controls.Add($panel)
    }
    Log-Message "Packages loaded successfully."
}

# Show the form
$form.ShowDialog()
