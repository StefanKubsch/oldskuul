﻿#############################
#							#
# deep4						#
# 							#
# presents					#
# 							#
# >_ps:oldskuul				#
# 							#
# (c) 2017 - present		#
# 							#
#############################

#region Define variables and constants / Preloading / PreCalc

# Force to use Powershell 5.1 and up.
#Requires -Version 5.1

# Force initialization of variables
Set-StrictMode -Version "Latest"

$localScriptRoot = $PSScriptRoot

# Loading used Namespaces / DLLs
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

$PSVersionTable.PSVersion

# PresentationCore needed for MediaPlayer object
Add-Type -AssemblyName PresentationCore

###############################################
# Custom LockBits class for pixel get/set     #
# ClassChunky.dll                             #
###############################################
$DLLPath = ".\ClassChunky\ClassChunky.dll"
$FileName = Join-Path $localScriptRoot $DLLPath
Add-Type -Path $FileName
$Chunky = [Chunky]

########################
# Init keyboardhandler #
########################
$ImportGetAsyncKeyState = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
'@

# load signatures and make members available
$GetKey = Add-Type -MemberDefinition $ImportGetAsyncKeyState -Name 'Win32' -PassThru

#####################
# General variables #
#####################
Set-Variable MainWindowWidth -Option Constant -Value 800
Set-Variable MainWindowHeight -Option Constant -Value 600

Set-Variable PartsRuntime -Option Constant -Value 10000

$ClearColor = [System.Drawing.Color]::FromArgb(12,6,63)
# "WhiteLinePen" is used for drawing lines in parts not using the "Background" image
$WhiteLinePen = New-Object System.Drawing.Pen White
Set-Variable WhiteLinePen.Width	-Option Constant -Value 0f
# Use System.Random function (.NET) since it´s a bit faster than the Get-Random cmdlet (Powershell)
$Random = New-Object System.Random
Set-Variable PI -Option Constant -Value 3.14

#############################
# Create MainWindow (Forms) #
#############################
$MainWindow 				= New-Object System.Windows.Forms.Form
# Add some pixels to Width & Height because of UI elements, so that the visible part of window is 800x600
$MainWindow.Size 			= New-Object System.Drawing.Size(($MainWindowWidth+16),($MainWindowHeight+39))
$MainWindow.FormBorderStyle = 'FixedSingle'
$MainWindow.AutoScaleMode	= 'None'
$MainWindow.BackColor 		= $ClearColor
$MainWindow.Text 			= ">_ps:oldskuul - press ESC to exit"

##############################
# Create some needed buffers #
##############################

$RB1BMP = New-Object System.Drawing.Bitmap($MainWindowWidth,50)
$RB2BMP = New-Object System.Drawing.Bitmap($MainWindowWidth,50)
$RB3BMP = New-Object System.Drawing.Bitmap($MainWindowWidth,50)

#########################################################
# Create GDI+ target from Windows Form and BoubleBuffer #
#########################################################
# Graphics object for screen rendering
$GDI 						= $MainWindow.CreateGraphics()
$GDI.Clear($ClearColor)
# Double Buffer graphics object
$BufferBMP 					= New-Object System.Drawing.Bitmap($MainWindowWidth,$MainWindowHeight)
$Buffer 					= [System.Drawing.Graphics]::FromImage($BufferBMP)
$Buffer.Clear($ClearColor)
# Set options for fastest performance
$GDI.CompositingMode		= 'SourceOver'
$GDI.CompositingQuality 	= 'HighSpeed'
$GDI.SmoothingMode 			= 'None'
$GDI.InterpolationMode 		= 'NearestNeighbor'
$GDI.PixelOffsetMode 		= 'Half'
$GDI.TextRenderingHint 		= 'SystemDefault'
$Buffer.CompositingMode		= 'SourceOver'
$Buffer.CompositingQuality	= 'HighSpeed'
$Buffer.SmoothingMode 		= 'None'
$Buffer.InterpolationMode	= 'NearestNeighbor'
$Buffer.PixelOffsetMode 	= 'Half'

######################
# Load graphic files #
######################
$Background	= [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\Background.png")

#########################################
# Establish Audio Player and load Audio #
#########################################
$AudioPlayer=New-Object System.Windows.Media.MediaPlayer
$AudioPlayer.Open($localScriptRoot + "\Audio\Audio1.mp3")

Do
{
	Start-Sleep -Seconds 0.5
   	$AudioDuration = $AudioPlayer.NaturalDuration.TimeSpan.TotalMilliseconds
}
Until ($AudioDuration)

$AudioPlayer.Volume=0.5

###########################
# Init Parallax Starfield #
###########################
$StarBrushPX1 = New-Object Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(100,100,150))
$StarBrushPX2 = New-Object Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150,150,200))
$StarBrushPX3 = New-Object Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200,200,255))
Set-Variable MaxStarsPX -Option Constant -Value 128
$StarsPXX 		= @{}
$StarsPXY		= @{}
$StarsPXZ		= @{}

For ($i=0; $i -lt $MaxStarsPX; $i++)
{
	$StarsPXX[$i] = $Random.Next(0, $MainWindowWidth)
  	$StarsPXY[$i] = $Random.Next(0, $MainWindowHeight)
	$StarsPXZ[$i] = $Random.Next(3, 6)
}

#####################
# Init 3D Starfield #
#####################
$StarBrush3D = New-Object Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(180,180,255))
Set-Variable MaxStars3D -Option Constant -Value 128
Set-Variable MaxDepth3D -Option Constant -Value 32
Set-Variable OrgX3D -Option Constant -Value ($MainWindowWidth -shr 1)
Set-Variable OrgY3D -Option Constant -Value ($MainWindowHeight -shr 1)
$Stars3DX = @{}
$Stars3DY = @{}
$Stars3DZ = @{}

For ($i=0; $i -lt $MaxStars3D; $i++)
{
	$Stars3DX[$i] = $Random.Next(-25,25)
	$Stars3DY[$i] = $Random.Next(-25,25)
	$Stars3DZ[$i] = $Random.Next(1,$MaxDepth3D)
}

####################
# Init FPS counter #
####################
$FPSFont 			= New-Object System.Drawing.Font("Calibri",9)
$FPSBrush			= New-Object Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200,200,200))
$script:FPS			= 0
$script:Timer		= 0
$script:FPSUpdate	= 0
$script:FPSFrames	= 0
Set-Variable FPSPosX -Option Constant -Value ($MainWindowWidth - 50)
Set-Variable FPSPosY -Option Constant -Value ($MainWindowHeight - 20)

#endregion

#region ReUsed Parts (Starfields, FPS counter etc.)

Function ParallaxStarfield()
{
	For ($i=0; $i -lt $MaxStarsPX; $i++)
	{
		$StarsPXX[$i] += $StarsPXZ[$i]

		If ($StarsPXX[$i] -ge $MainWindowWidth)
		{
   	 		$StarsPXX[$i] = 0
			$StarsPXY[$i] = $Random.Next(0,$MainWindowHeight)
	  		$StarsPXZ[$i] = $Random.Next(3,6)
		}

		Switch ($StarsPXZ[$i])
		{
			3 { $Buffer.FillEllipse($StarBrushPX1,$StarsPXX[$i],$StarsPXY[$i],3,3) }
			4 { $Buffer.FillEllipse($StarBrushPX2,$StarsPXX[$i],$StarsPXY[$i],4,4) }
			5 { $Buffer.FillEllipse($StarBrushPX3,$StarsPXX[$i],$StarsPXY[$i],5,5) }
		}
	}
}

Function 3DStarfield()
{
	For ($i=0; $i -lt $MaxStars3D; $i++)
	{
		$Stars3DZ[$i] -= 0.19

		If ($Stars3DZ[$i] -lt 0)
		{
			$Stars3DX[$i] = $Random.Next(-25,25)
			$Stars3DY[$i] = $Random.Next(-25,25)
			$Stars3DZ[$i] = $Random.Next(1,$MaxDepth3D)
		}

		$F = 128 / $Stars3DZ[$i]
		$Size = (1 - ($Stars3DZ[$i]) / $MaxDepth3D) * 6
		$Buffer.FillEllipse($StarBrush3D,($Stars3DX[$i] *$F + $OrgX3D),($Stars3DY[$i] * $F + $OrgY3D),$Size,$Size)
	}
}

Function FPSCounter()
{
	$script:Timer = [System.Environment]::TickCount

	# Keyboardhandling and Exit on "ESC"
	If ($GetKey::GetAsyncKeyState(27) -eq -32767)
	{
		$AudioPlayer.Stop()
		$AudioPlayer.Close()
		$MainWindow.Close()
		Exit
	}

	If ($Timer - $FPSUpdate -ge 1000)
	{
		$script:FPS = $FPSFrames
		$script:FPSUpdate = $Timer
		$script:FPSFrames = 0
	}

	++$script:FPSFrames
	$Buffer.DrawString("$FPS fps",$FPSFont,$FPSBrush,$FPSPosX,$FPSPosY)
}

Function ComposeScreen($Drawlines)
{
	if ($Drawlines -eq $true)
	{
		$Buffer.DrawLine($WhiteLinePen,0,151,$MainWindowWidth,151)
		$Buffer.DrawLine($WhiteLinePen,0,152,$MainWindowWidth,152)
		$Buffer.DrawLine($WhiteLinePen,0,153,$MainWindowWidth,153)
		$Buffer.DrawLine($WhiteLinePen,0,154,$MainWindowWidth,154)
		$Buffer.DrawLine($WhiteLinePen,0,155,$MainWindowWidth,155)

		$Buffer.DrawLine($WhiteLinePen,0,441,$MainWindowWidth,441)
		$Buffer.DrawLine($WhiteLinePen,0,442,$MainWindowWidth,442)
		$Buffer.DrawLine($WhiteLinePen,0,443,$MainWindowWidth,443)
		$Buffer.DrawLine($WhiteLinePen,0,444,$MainWindowWidth,444)
		$Buffer.DrawLine($WhiteLinePen,0,445,$MainWindowWidth,445)
	}

	FPSCounter

	# Render to screen
	$GDI.DrawImage($BufferBMP,0,0,$MainWindowWidth,$MainWindowHeight)
	Start-Sleep -Milliseconds 0.01
}

#endregion

#region Compiled Parts

Function IntroText()
{
	# Text / XPos / YPos / Wait / R / G / B
	Set-Variable IntroTextArray -Option Constant -Value @(("state",250,150,1,250,250,250),
						("of",305,210,1,250,250,250),
						("demoscene",220,253,1,250,250,250),
						("not",165,105,10,250,250,250),
						(">_ps:oldskuul",300,500,10,250,0,0))
	$IntroFont		= New-Object System.Drawing.Font("Calibri",60)

	for ($i=0; $i -le 4; $i++)
	{
		$R1 = 12
		$R = 12
		$G1 = 6
		$G = 6
		$B1 = 63
		$B = 63

		If ($i -eq 4)
		{
			$AudioPlayer.Play()
		}

		Start-Sleep -Milliseconds $IntroTextArray[$i][3]

		for ($j=0; $j -lt 128; $j++)
		{
				If ($R1 -lt $IntroTextArray[$i][4]) { $R1 += 2 }
				If ($G1 -lt $IntroTextArray[$i][5]) { $G1 += 2 }
				If ($B1 -lt $IntroTextArray[$i][6]) { $B1 += 2 }

				$IntroBrush = New-Object Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($R1,$G1,$B1))
				$Buffer.DrawString($IntroTextArray[$i][0],$IntroFont,$IntroBrush,$IntroTextArray[$i][1],$IntroTextArray[$i][2])
				$GDI.DrawImage($BufferBMP,0,0,$MainWindowWidth,$MainWindowHeight)
        }
	}

	$bgR = 12
	$R = 12
	$bgG = 6
	$G = 6
	$bgB = 63
	$B = 63

	for ($i=0; $i -lt 50; $i++)
	{
		If ($bgR -lt 250) { $bgR += 5 }
		If ($bgG -lt 250) { $bgG += 5 }
		If ($bgB -lt 250) { $bgB += 5 }

		$Buffer.Clear([System.Drawing.Color]::FromArgb($bgR,$bgG,$bgB))

		for ($j=0; $j -lt 5; $j++)
		{
			If ($j -eq 4)
			{
				$IntroBrush = New-Object Drawing.SolidBrush([System.Drawing.Color]::FromArgb($IntroTextArray[$j][4],$bgG,$bgB))
			}
			Else
			{
				$IntroBrush = New-Object Drawing.SolidBrush([System.Drawing.Color]::FromArgb($IntroTextArray[$j][4],$IntroTextArray[$j][5],$IntroTextArray[$j][6]))
			}

			$Buffer.DrawString($IntroTextArray[$j][0],$IntroFont,$IntroBrush,$IntroTextArray[$j][1],$IntroTextArray[$j][2])
	    }

		$GDI.DrawImage($BufferBMP,0,0,$MainWindowWidth,$MainWindowHeight)
	}

	$R = 254
	$G = 254
	$B = 254

	For ($i = 255; $i -gt 0; $i -= 5)
	{
		If ($R -ge 12) { $R = $i }
		If ($G -ge 6) { $G = $i }
		If ($B -ge 63) { $B = $i }

		$Buffer.Clear([System.Drawing.Color]::FromArgb($R,$G,$B))
		$GDI.DrawImage($BufferBMP,0,0,$MainWindowWidth,$MainWindowHeight)
    }
}

# Parallax Starfield, Rasterbars & Bouncing Logo
Function Rasterbars($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Rasterbars
	$RBPen = New-Object System.Drawing.Pen Red
	$RBPen.Width = 5
	Set-Variable RB1Colors -Option Constant -Value @((66,66,24),(106,106,44),(156,156,68),(213,213,97),(241,241,111),(213,213,97),(156,156,68),(106,106,44),(66,66,24))
	Set-Variable RB2Colors -Option Constant -Value @((24,66,66),(44,106,106),(68,156,156),(97,213,213),(111,241,241),(97,213,213),(68,156,156),(44,106,106),(24,66,66))
	Set-Variable RB3Colors -Option Constant -Value @((66,24,66),(106,44,106),(156,68,156),(213,97,213),(241,111,241),(213,97,213),(156,68,156),(106,44,106),(66,24,66))
	# Start-Position / Direction / Speed
	$RBParams		 				= @((150,"Down",2),(400,"Up",2),(250,"Up",2))
	Set-Variable RBMaxY -Option Constant -Value 400
	Set-Variable RBMinY -Option Constant -Value 150

	# Pre-draw rasterbars in matching bitmaps
	For ($i=0; $i -lt 9; $i++)
	{
		$Spacing = $i * 5
		$RBPen.Color = [Drawing.Color]::FromArgb($RB1Colors[$i][0],$RB1Colors[$i][1],$RB1Colors[$i][2])
		$RBBuffer = [System.Drawing.Graphics]::FromImage($RB1BMP)
		$RBBuffer.DrawLine($RBPen,0,$Spacing,$MainWindowWidth,$Spacing)

		$RBPen.Color = [Drawing.Color]::FromArgb($RB2Colors[$i][0],$RB2Colors[$i][1],$RB2Colors[$i][2])
		$RBBuffer = [System.Drawing.Graphics]::FromImage($RB2BMP)
		$RBBuffer.DrawLine($RBPen,0,$Spacing,$MainWindowWidth,$Spacing)

		$RBPen.Color = [Drawing.Color]::FromArgb($RB3Colors[$i][0],$RB3Colors[$i][1],$RB3Colors[$i][2])
		$RBBuffer = [System.Drawing.Graphics]::FromImage($RB3BMP)
		$RBBuffer.DrawLine($RBPen,0,$Spacing,$MainWindowWidth,$Spacing)
	}

	# Init bouncing Logo
	$LogoImage = [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\BouncingLogo.png")
	$LogoDir = "Right"
	$LogoX = 9
	Set-Variable LogoMaxX -Option Constant -Value 237
	Set-Variable LogoMinX -Option Constant -Value 9

	Do
	{
		$Buffer.Clear($ClearColor)

		ParallaxStarfield

		$Buffer.DrawImage($Background,0,150)

		# Rasterbar 1
		Switch ($RBParams[0][1])
		{
			"Up" { $RBParams[0][0] -= $RBParams[0][2] }
			"Down" { $RBParams[0][0] += $RBParams[0][2] }
		}

		Switch ($RBParams[0][0])
		{
			$RBMaxY { $RBParams[0][1] = "Up" }
			$RBMinY { $RBParams[0][1] = "Down" }
		}

		# Rasterbar 2
		Switch ($RBParams[1][1])
		{
			"Up" { $RBParams[1][0] -= $RBParams[1][2] }
			"Down" { $RBParams[1][0] += $RBParams[1][2] }
		}

		Switch ($RBParams[1][0])
		{
			$RBMaxY { $RBParams[1][1] = "Up" }
			$RBMinY { $RBParams[1][1] = "Down" }
		}

		#Rasterbar 3
		Switch ($RBParams[2][1])
		{
			"Up" { $RBParams[2][0] -= $RBParams[2][2] }
			"Down" { $RBParams[2][0] += $RBParams[2][2] }
		}

		Switch ($RBParams[2][0])
		{
			$RBMaxY { $RBParams[2][1] = "Up" }
			$RBMinY { $RBParams[2][1] = "Down" }
		}

		# BouncingLogo
		Switch ($LogoDir)
		{
			"Right" { $LogoX += 3 }
			"Left" { $LogoX -= 3 }
		}

		Switch ($LogoX)
		{
			$LogoMaxX { $LogoDir = "Left" }
			$LogoMinX { $LogoDir = "Right" }
		}

		# Draw everything to buffer
		$Buffer.DrawImage($RB1BMP,0,$RBParams[0][0])
		$Buffer.DrawImage($RB2BMP,0,$RBParams[1][0])

		$Buffer.DrawImage($LogoImage,$LogoX,(230 + (80 * [System.Math]::Sin($LogoX * $PI / 128))))

		$Buffer.DrawImage($RB3BMP,0,$RBParams[2][0])

		ComposeScreen($false)
	} Until ($Timer -ge $StopTime)

	$LogoImage.Dispose()
}

# 3D Starfield, Plasma
Function Plasma($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Plasma
	Set-Variable PlasmaWidth -Option Constant -Value $MainWindowWidth
	Set-Variable PlasmaHeight -Option Constant -Value 293
	Set-Variable PlasmaSpacing -Option Constant -Value 5
	$PlasmaCount1 		 = 5
	$PlasmaCount2 		 = 125
	$PlasmaCount3 		 = 250
	$PlasmaSpeed1 		 = 3
	$PlasmaSpeed2 		 = 6
	$PlasmaSpeed3 		 = 9
	$PlasmaBrush		 = New-Object Drawing.SolidBrush ("Black")
	$Plasmagfx 			 = New-Object $Chunky($BufferBMP)

	Do
	{
		$Buffer.Clear($ClearColor)

		3DStarfield

		$Buffer.FillRectangle($PlasmaBrush,0,150,$MainWindowWidth,295)

		# Plasma
		$Plasmagfx.Lock()

		If ($PlasmaCount1 -gt 255 -or $PlasmaCount1 -le 1) { $PlasmaSpeed1 = -$PlasmaSpeed1 }
		If ($PlasmaCount2 -gt 255 -or $PlasmaCount2 -le 1) { $PlasmaSpeed2 = -$PlasmaSpeed2 }
		If ($PlasmaCount3 -gt 255 -or $PlasmaCount3 -le 1) { $PlasmaSpeed3 = -$PlasmaSpeed3 }

		$PlasmaCount1 += $PlasmaSpeed1
		$PlasmaCount2 -= $PlasmaSpeed2
		$PlasmaCount3 += $PlasmaSpeed3

		For ($y = $Plasmaheight; $y -ge 0; $y = $y - $PlasmaSpacing)
 	    {
       		For ($x = $PlasmaWidth; $x -ge 0; $x = $x - $PlasmaSpacing)
   	    	{
				[int] $Color = (128 * [System.Math]::Sin($x / 64.0)) + (64 * [System.Math]::Cos($y / 64.0))
				$Plasmagfx.SetPixel($x,$y + 150,([System.Drawing.Color]::FromArgb(($Color + $PlasmaCount3) -band 255,($Color + $PlasmaCount1) -band 255,($Color + $PlasmaCount2) -band 255)))
			}
    	}

		$Plasmagfx.Release()

		ComposeScreen($true)
	} Until ($Timer -ge $StopTime)
}

# 3D Starfield and FilledVectorCube
Function FilledVectorCube($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Vectorcube
	$CubeX 				= @{}
	$CubeY 				= @{}
	Set-Variable CenterX -Option Constant -Value ($MainWindowWidth -shr 1)
	Set-Variable CenterY -Option Constant -Value ($MainWindowHeight -shr 1)
	$CubeFaceBrushes 	= @{}
	$CubeFaceColors		= @([System.Drawing.Color]::FromArgb(185,242,145),[System.Drawing.Color]::FromArgb(80,191,148),[System.Drawing.Color]::FromArgb(94,89,89),
							[System.Drawing.Color]::FromArgb(247,35,73),[System.Drawing.Color]::FromArgb(255,132,94),[System.Drawing.Color]::FromArgb(246,220,133))
	$CubeDef 			= @((-100,-100,-100),(-100,-100,100),(-100,100,-100),(-100,100,100),(100,-100,-100),(100,-100,100),(100,100,-100),(100,100,100))
	$CubeFaces 			= @((0,1,3,2),(4,0,2,6),(5,4,6,7),(1,5,7,3),(0,1,5,4),(2,3,7,6))
	Set-Variable CubeNumFaces -Option Constant -Value 5
	$Angle				= 0.02
	$CosA 				= [System.Math]::Cos($Angle)
	$SinA 				= [System.Math]::Sin($Angle)

	# for sort
	$avgZ				= @{}
	$Order				= @{}
	$Points				= @{}


	For ($i=0; $i -le $CubeNumFaces; $i++)
	{
 	  	$CubeFaceBrushes[$i] = New-Object Drawing.SolidBrush($CubeFaceColors[$i])
	}

	Do
	{
		$Buffer.Clear($ClearColor)

		3DStarfield

		$Buffer.DrawImage($Background,0,150)

		# Filled VectorCube
		For ($i=0; $i -lt 8; $i++)
		{
			# x-rotation
			$y = $CubeDef[$i][1]
			$CubeDef[$i][1] = $y * $CosA - $CubeDef[$i][2] * $SinA

			# y-rotation
			$z = $CubeDef[$i][2] * $CosA + $y * $SinA
		   	$CubeDef[$i][2] = $z * $CosA + $CubeDef[$i][0] * $SinA

    		# z-rotation
			$x = $CubeDef[$i][0] * $CosA - $z * $SinA
			$CubeDef[$i][0] = $x * $CosA - $CubeDef[$i][1] * $SinA
        	$CubeDef[$i][1] = $CubeDef[$i][1] * $CosA + $x * $SinA

			# 2D projection & translate
			$CubeX[$i] = $CenterX + $CubeDef[$i][0]
			$CubeY[$i] = $CenterY + $CubeDef[$i][1]
		}

		# selection-sort of depth/faces
		For ($i=0; $i -le $CubeNumFaces; $i++)
		{
			$avgZ[$i] = ($CubeDef[$CubeFaces[$i][0]][2] + $CubeDef[$CubeFaces[$i][1]][2] + $CubeDef[$CubeFaces[$i][2]][2] + $CubeDef[$CubeFaces[$i][3]][2]) -shr 2
			$Order[$i] = $i
  		}

		For ($i=0; $i -lt $CubeNumFaces; $i++)
		{
	       	$Min = $i

		    For ($j = $i + 1; $j -le $CubeNumFaces; ++$j)
			{
            	If ($avgZ[$j] -lt $avgZ[$Min])
				{
    	            $Min = $j
				}
			}

           	$avgZ[$i], $avgZ[$Min] = $avgZ[$Min], $avgZ[$i]
   	        $Order[$i], $Order[$Min] = $Order[$Min], $Order[$i]
 	    }

		For ($i=0; $i -le $CubeNumFaces; $i++)
		{
			$Points = @((New-Object Drawing.Point($CubeX[$CubeFaces[$Order[$i]][0]],$CubeY[$CubeFaces[$Order[$i]][0]])),(New-Object Drawing.Point($CubeX[$CubeFaces[$Order[$i]][1]],$CubeY[$CubeFaces[$Order[$i]][1]])),(New-Object Drawing.Point($CubeX[$CubeFaces[$Order[$i]][2]],$CubeY[$CubeFaces[$Order[$i]][2]])),(New-Object Drawing.Point($CubeX[$CubeFaces[$Order[$i]][3]],$CubeY[$CubeFaces[$Order[$i]][3]])))
        	$Buffer.FillPolygon($CubeFaceBrushes[$Order[$i]],$Points)
		}

		ComposeScreen($false)
	} Until ($Timer -ge $StopTime)
}

# Parallax Starfield, Fire
Function Fire($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Fire
	Set-Variable FireWidth -Option Constant -Value 128
	Set-Variable FireHeight -Option Constant -Value 64
	$FireChunky		= New-Object System.Drawing.Bitmap($FireWidth,$FireHeight)
	$Firegfx 		= New-Object $Chunky($FireChunky)

	Do
	{
		$Buffer.Clear($ClearColor)

		ParallaxStarfield

		# Fire
		$Firegfx.Lock()

		For ($x = $FireWidth; $x -ge 0; $x -= 8)
	    {
	        $RandomNumber = $Random.Next(0,($FireWidth - 1))
	        $Firegfx.SetPixel($RandomNumber,$FireHeight - 1,"Yellow")
	        $Firegfx.SetPixel($RandomNumber + 1,$FireHeight - 1,"Red")
 	   }

		For ($y=1; $y -lt $FireHeight; ++$y)
 	    {
			For ($x=0; $x -lt $FireWidth; ++$x)
  		    {
				If (($Random.Next() -band 31) -eq 0)
				{
	        		$Firegfx.SetPixel($x,$y,"Black")
				}
				Else
				{
				   	$c = $Firegfx.GetPixel($x,$y)
            		$d = $Firegfx.GetPixel($x,$y - 1)
            		$e = $Firegfx.GetPixel($x - 1,$y)
            		$r = $Firegfx.GetPixel($x + 1,$y - 1)

					$Firegfx.SetPixel($x,$y - 1,[System.Drawing.Color]::FromArgb((($c.R + $d.R + $e.R + $r.R) -shr 2),(($c.G + $d.G + $e.G + $r.G) -shr 2),(($c.B + $d.B + $e.B + $r.B) -shr 2)))
				}
        	}
    	}

		$Firegfx.Release()
		$Buffer.DrawImage($FireChunky,0,151,$MainWindowWidth,291)

		ComposeScreen($true)
	} Until ($Timer -ge $StopTime)
}

# 3D Starfield and RotoZoomer
Function Rotozoomer($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Rotozoomer
	$RotoZoomer	= [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\RotoZoomer.png")
	$RotoAngle	= 0
	Set-Variable RotoXPos -Option Constant -Value ($MainWindowWidth -shr 1)
	Set-Variable RotoYPos -Option Constant -Value ( $MainWindowHeight -shr 1)
	Set-Variable RotoHalfX -Option Constant -Value ($RotoZoomer.Width / -2)
	Set-Variable RotoHalfY -Option Constant -Value ($RotoZoomer.Height / -2)
	Set-Variable RotoWidth -Option Constant -Value $RotoZoomer.Width
	Set-Variable Rotoheight -Option Constant -Value $RotoZoomer.Height

	Do
	{
		$Buffer.Clear($ClearColor)

		3DStarfield

		$Buffer.DrawImage($Background,0,150)

		# Rotozoomer
		$RotoAngle += 3

		$RotM = New-Object System.Drawing.Drawing2D.Matrix
		$RotM.Translate($RotoHalfX,$RotoHalfY,[System.Drawing.Drawing2D.MatrixOrder]::Append)
	    $RotM.RotateAt($RotoAngle,(New-Object Drawing.Point(0,0)),[System.Drawing.Drawing2D.MatrixOrder]::Append)
 	 	$gPath = New-Object System.Drawing.Drawing2D.GraphicsPath
		$gPath.AddPolygon(@((New-Object Drawing.Point(0,0)),(New-Object Drawing.Point($RotoWidth,0)),(New-Object Drawing.Point(0,$Rotoheight))))
 	    $gPath.Transform($RotM)
 	    $pts = $gPath.PathPoints
		$gUnit = New-Object System.Drawing.GraphicsUnit
 	    $Img = [System.Drawing.Rectangle]::Round($RotoZoomer.GetBounds([ref] $gUnit))
 	    $Points = @((New-Object Drawing.Point($Img.Left,$Img.Top)),(New-Object Drawing.Point($Img.Right,$Img.Top)),(New-Object Drawing.Point($Img.Right,$Img.Bottom)),(New-Object Drawing.Point($Img.Left,$Img.Bottom)))
		$gPath = New-Object System.Drawing.Drawing2D.GraphicsPath($Points,@([byte] [System.Drawing.Drawing2D.PathPointType]::Start,[byte] [System.Drawing.Drawing2D.PathPointType]::Line,[byte] [System.Drawing.Drawing2D.PathPointType]::Line,[byte] [System.Drawing.Drawing2D.PathPointType]::Line))
  	    $gPath.Transform($RotM)
		$rect = [System.Drawing.Rectangle]::Round($gPath.GetBounds())
		$Out = New-Object System.Drawing.Bitmap($rect.Width,$rect.Height)
 	    $gOut = [System.Drawing.Graphics]::FromImage($Out)
 	    $mOut = New-Object System.Drawing.Drawing2D.Matrix
 	    $mOut.Translate($Out.Width -shr 1,$Out.Height -shr 1,[System.Drawing.Drawing2D.MatrixOrder]::Append)
 	    $gOut.Transform = $mOut
 	    $gOut.DrawImage($RotoZoomer,$pts)

		# Draw rotated image to buffer
		$Buffer.DrawImage($Out,$RotoXPos - $RotoWidth - 50,$RotoYPos - $Rotoheight + 50,800,600)

		ComposeScreen($false)
	} Until ($Timer -ge $StopTime)

	$RotoZoomer.Dispose()
}

# Parallax Starfield, Bobs and SineScroller
Function SineScroller($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Sine Scroller
	$ScrollX			= $MainWindowWidth - 1
	$ScrollY		 	= $MainWindowHeight - 100
	Set-Variable ScrollCharW -Option Constant -Value 46
	Set-Variable ScrollCharH -Option Constant -Value 48
	Set-Variable ScrollSpeed -Option Constant -Value 8
	$ScrollUnit 		= [System.Drawing.GraphicsUnit]::Pixel
	$ScrollCharPNG 		= [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\SinusScrollerChars.png")
	Set-Variable ScrollCharMap -Option Constant -Value "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789?!().,"
	Set-Variable ScrollText -Option Constant -Value "YEAH! WELCOME TO OLDSKUUL, THE FIRST TRACKMO CODED IN POWERSHELL...HOPE YOU ENJOY THE SHOW..."
	Set-Variable ScrollTextLength -Option Constant -Value $ScrollText.Length
	Set-Variable ScrollLength -Option Constant -Value ($ScrollText.Length * ($ScrollCharW + 9))
	$sx 				= $ScrollX

	# Init Bobs
	Set-Variable MaxBobs -Option Constant -Value 24
	$BobXCoord1 	= @{}
	$BobYCoord1	 	= @{}
	$BobXCoord2 	= @{}
	$BobYCoord2 	= @{}
	$BobA 			= 0
	$BobB			= 40
	$Bob1 			= [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\Bob1.png")
	$Bob2 			= [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\Bob2.png")

	For ($i=0; $i -lt 512; $i++)
	{
		$TempCalc = ($i * 0.703125) * 0.0174532

		$BobXCoord1[$i] = [System.Math]::Sin($TempCalc) * 300 + 300
		$BobYCoord1[$i] = [System.Math]::Cos($TempCalc) * 150 + 150
		$BobXCoord2[$i] = [System.Math]::Cos($TempCalc) * 300 + 300
		$BobYCoord2[$i] = [System.Math]::Sin($TempCalc) * 150 + 150
	}

	Do
	{
		$Buffer.Clear($ClearColor)

		ParallaxStarfield

		$Buffer.DrawImage($Background,0,150)

		# Sine Scroller
		$sx = $ScrollX

		For ($i=0; $i -lt $ScrollTextLength; $i++)
		{
			$CharX = 0

			For ($j=0; $j -lt 42; $j++)
			{
				If ($ScrollText[$i] -eq $ScrollCharMap[$j] -and $sx -lt $MainWindowWidth -and $sx -gt -$ScrollCharW)
				{
					$Buffer.DrawImage($ScrollCharPNG,$sx,($ScrollY+[System.Math]::Sin(0.02 * $sx) * 30),(New-Object System.Drawing.Rectangle($CharX,0,$ScrollCharW,$ScrollCharH)),$ScrollUnit)
					Break
				}
				$CharX += $ScrollCharW + 2
			}

			$sx += $ScrollCharW + 9
		}

		$ScrollX -= $ScrollSpeed

		If ($ScrollX -lt -$ScrollLength)
		{
			$ScrollX = $MainWindowWidth - 1
		}

		# Bobs
		For ($i=0; $i -le $MaxBobs; $i++)
		{
			$Buffer.DrawImage($Bob1,$BobXCoord1[$BobA -band 511] + 80,$BobYCoord1[$BobB -band 511] + 100)
			$Buffer.DrawImage($Bob2,$BobXCoord2[$BobA + 512 -band 511] + 80,$BobYCoord2[$BobB + 512 -band 511] + 100)

			$BobA += 20
			$BobB += 20
		}

		$BobA += 8
		$BobB += 10

		ComposeScreen($false)
	} Until ($Timer -ge $StopTime)

	$ScrollCharPNG.Dispose()
	$Bob1.Dispose()
	$Bob2.Dispose()
}

# 3D Starfield, Tunnel
Function Tunnel($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Tunnel
	Set-Variable TunnelTextureSize -Option Constant -Value 256
	Set-Variable TunnelScreenWidth -Option Constant -Value 128
	Set-Variable TunnelScreenHeight -Option Constant -Value 64
	$TunnelDistance 			= New-Object 'object[,]' ($TunnelScreenWidth -shl 1), ($TunnelScreenHeight -shl 1)
	$TunnelAngle    			= New-Object 'object[,]' ($TunnelScreenWidth -shl 1), ($TunnelScreenHeight -shl 1)
	$TunnelSpeedX 	= 2.15
	$TunnelSpeedY 	= 2.15
	$TunnelAnim		= 0
	Set-Variable TunnelWidth -Option Constant -Value ($TunnelScreenWidth -shr 1)
	Set-Variable TunnelHeight -Option Constant -Value ($TunnelScreenHeight -shr 1)
	$TunnelChunky				= New-Object System.Drawing.Bitmap($TunnelScreenWidth,$TunnelScreenHeight)
	$Tunnelgfx 					= New-Object $Chunky($TunnelChunky)
	$TextureBMP			 		= [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\TunnelTexture.png")

	# Load & lock tunnel texture
	$TTgfx = New-Object $Chunky($TextureBMP)
	$TTgfx.Lock()

	# Generate distance and angle tables for tunnel
	For ($x=0; $x -le (($TunnelScreenWidth -shl 1) - 1); $x++)
	{
		For ($y=0; $y -le (($TunnelScreenHeight -shl 1) - 1); $y++)
		{
 	 	  	$TunnelDistance[$x,$y] = [int] (32.0 * $TunnelTextureSize / [System.Math]::Sqrt(($x - $TunnelScreenWidth) * ($x - $TunnelScreenWidth) + ($y - $TunnelScreenHeight) * ($y - $TunnelScreenHeight))) -band ($TunnelTextureSize-1)
			$AngleTemp = (0.5 * $TunnelTextureSize * [System.Math]::ATan2($y - $TunnelScreenHeight, $x - $TunnelScreenWidth) / $PI)
    		$TunnelAngle[$x,$y] = [int] (256 - $AngleTemp) -band 255
		}
	}

	$MX = $TunnelTextureSize * $TunnelSpeedX
	$MY = $TunnelTextureSize * $TunnelSpeedY

	Do
	{
		$Buffer.Clear($ClearColor)

		3DStarfield

		# Tunnel
		$Tunnelgfx.Lock()

		$TunnelAnim += 0.01

		$SX = [int] ($MX * $TunnelAnim)
		$SY = [int] ($MY * $TunnelAnim)

		$LX = [int] ($TunnelWidth * [System.Math]::Cos($TunnelAnim * 4.0)) + $TunnelWidth
		$LY = [int] ($TunnelHeight * [System.Math]::Sin($TunnelAnim * 6.0)) + $TunnelHeight

		For ($y=0; $y -lt $TunnelScreenHeight; $y++)
		{
			For ($x=0; $x -lt $TunnelScreenWidth; $x++)
			{
				$Color = $TTgfx.GetPixel((($TunnelDistance[($x + $LX),($y + $LY)] + $SX) -band 255),(($TunnelAngle[($x + $LX),($y + $LY)] + $SY) -band 255))
				$Tunnelgfx.SetChunk($Color)
			}
		}

		$Tunnelgfx.Release()

		$Buffer.DrawImage($TunnelChunky,0,150,$MainWindowWidth,295)

		ComposeScreen($true)
	} Until ($Timer -ge $StopTime)

	$TextureBMP.Dispose()
}

# Parallax Starfield, Metaballs 2D
Function Metaballs($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Metaballs
	Set-Variable MetaballsWidth -Option Constant -Value 200
	Set-Variable MetaballsHeight -Option Constant -Value 80
	$MetaBallsChunky	= New-Object System.Drawing.Bitmap($MetaballsWidth,$MetaballsHeight)
	$MetaBallsgfx 		= New-Object $Chunky($MetaBallsChunky)

	$MetaB1x 			= 60
	$MetaB1y			= 60
	$MetaB1xvel			= 4
	$MetaB1yvel			= 2

	$MetaB2x 			= 90
	$MetaB2y			= 40
	$MetaB2xvel 		= 4
	$MetaB2yvel 		= 6

	$MetaB3x			= 100
	$MetaB3y			= 10
	$MetaB3xvel 		= 5
	$MetaB3yvel 		= -3

	Do
	{
		$Buffer.Clear($ClearColor)

		ParallaxStarfield

		$Metaballsgfx.Lock()

		$MetaB1x += $MetaB1xvel
		If ($MetaB1x -gt $MetaballsWidth -or $MetaB1x -lt 0) { $MetaB1xvel *= -1 }

		$MetaB1y += $MetaB1yvel
		If ($MetaB1y -gt $MetaballsHeight -or $MetaB1y -lt 0 ) { $MetaB1yvel *= -1 }

		$MetaB2x += $MetaB2xvel
		If ($MetaB2x -gt $MetaballsWidth -or $MetaB2x -lt 0 ) { $MetaB2xvel *= -1 }

		$MetaB2y += $MetaB2yvel
		If ($MetaB2y -gt $MetaballsHeight -or $MetaB2y -lt 0 ) { $MetaB2yvel *= -1 }

		$MetaB3x += $MetaB3xvel
		If ($MetaB3x -gt $MetaballsWidth -or $MetaB3x -lt 0 ) { $MetaB3xvel *= -1 }

		$MetaB3y += $MetaB3yvel
		If ($MetaB3y -gt $MetaballsHeight -or $MetaB3y -lt 0 ) { $MetaB3yvel *= -1 }

		For ($y=0; $y -lt $MetaballsHeight; $y++)
		{
        	For ($x=0; $x -lt $MetaballsWidth; $x++)
         	{
				$BallSum = 0.3 / [System.Math]::Sqrt(($x - $MetaB1x) * ($x - $MetaB1x) + ($y - $MetaB1y) * ($y - $MetaB1y))
                $BallSum += 0.3 / [System.Math]::Sqrt(($x - $MetaB2x) * ($x - $MetaB2x) + ($y - $MetaB2y) * ($y - $MetaB2y))
                $BallSum += 0.3 / [System.Math]::Sqrt(($x - $MetaB3x) * ($x - $MetaB3x) + ($y - $MetaB3y) * ($y - $MetaB3y))

				$Color = [System.Drawing.Color]::FromArgb(70,0,70)

				If ($BallSum -gt 0.035)
				{
                	$Color = [System.Drawing.Color]::FromArgb(0,250,0)
                }
				ElseIf ($BallSum -gt 0.026)
				{
					$Color = [System.Drawing.Color]::FromArgb(0,((10000 * $BallSum) - 100),0)
				}

				$Metaballsgfx.SetChunk($Color)
			}
        }

		$Metaballsgfx.Release()

		$Buffer.DrawImage($MetaballsChunky,0,150,$MainWindowWidth,295)

		ComposeScreen($true)
	} Until ($Timer -ge $StopTime)
}

# Parallax Starfield, DotTunnel
Function DotTunnel($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Dot Tunnel
	$DotTunnelWidth 		= 800
	$DotTunnelHeight		= 295
	$DotTunnelRings 		= 40
	$DotTunnelSpace 		= 8
	$DotTunnelRadius 		= 1500
	$DotTunnelCenterX		= $DotTunnelWidth -shr 1
	$DotTunnelCenterY		= $DotTunnelHeight -shr 1
	$DotTunnelRAD2DEG 		= 4 * [System.Math]::Atan(1) / 180
	$DotTunnelMove 			= 0.0
	$DotTunnelAdd 			= 0.06
	$DotTunnelgfx 			= New-Object $Chunky($BufferBMP)
	$DotTunnelBrush		 	= New-Object Drawing.SolidBrush ($ClearColor)
	$RadY1 					= 300 * [System.Math]::Sin($DotTunnelAdd * $DotTunnelRAD2DEG) + $DotTunnelRadius
    $RadY2 					= 300 * [System.Math]::Cos($DotTunnelAdd * $DotTunnelRAD2DEG) + $DotTunnelRadius

	Do
	{
   		$Buffer.Clear($ClearColor)

		ParallaxStarfield

		$Buffer.FillRectangle($DotTunnelBrush,0,150,$DotTunnelWidth,$DotTunnelHeight)

		# Dot Tunnel
		$DotTunnelgfx.Lock()

		$Depth 			= 20
		$DepthAdd 		= $Depth / $DotTunnelRings
 	    $Depth 			+= $DotTunnelMove
		$Tick 			= 0.3
	    $DotTunnelMove 	-= $Tick
	    $Warp			-= $Tick
	    $Factor 		= $Warp

		If ($DotTunnelMove -le 0)
		{
			$DotTunnelMove += $DepthAdd * 2
			$Warp -= $DepthAdd * 60
		}

		For ($j=0; $j -lt $DotTunnelRings; $j++)
		{
 	        $SinA = 260 * [System.Math]::Sin($Factor * $DotTunnelRAD2DEG)

			For ($i=360; $i -ge 0; $i-=$DotTunnelSpace)
			{
				$Calc = $DotTunnelRAD2DEG * ($i + $DotTunnelAdd)
				$x = [int] (($RadY1 * [System.Math]::Sin($Calc) + $SinA) / $Depth) + $DotTunnelCenterX
    	        $y = [int] (($RadY2 * [System.Math]::Cos($Calc) + $SinA) / $Depth) + $DotTunnelCenterY

				If ($x -gt 0 -and $x -lt $DotTunnelWidth -and $y -gt 0 -and $y -lt $DotTunnelHeight)
				{
					$DotTunnelgfx.SetPixel($x,$y + 150,"White")
				}
			}

			$Factor += 15
    	    $Depth -= $DepthAdd
		}

		$DotTunnelgfx.Release()

		ComposeScreen($true)
	} Until ($Timer -ge $StopTime)
}

# 3D Starfield, VectorBalls
Function VectorBalls($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Vectorballs
	$VectorBallsBob 	= [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\VectorBall.png")
	Set-Variable VectorBallsNum -Option Constant -Value 47
	$VectorBallsDefX   	= @(-9,-8,-5,-4,-3,-1,0,1,3,4,5,7,-9,-7,-5,-1,3,5,7,9,-9,-7,-5,-4,-1,0,3,4,5,7,8,9,-9,-7,-5,-1,3,9,-9,-8,-5,-4,-3,-1,0,1,3,9)
	$VectorBallsDefY	= @(2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-2,-2,-2,-2,-2,-2,-2,-2,-2,-2)
	$VectorBallsDefZ	= @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
	$VectorBallsCoordX 	= @{}
	$VectorBallsCoordY 	= @{}
	$VectorBallsCoordZ 	= @{}
	$AngleX				= 0
	$AngleY				= 0
	$AngleZ				= 0

	Do
	{
		$Buffer.Clear($ClearColor)

		3DStarfield

		$Buffer.DrawImage($Background,0,150)

		# VectorBalls
		$AngleXTemp = $AngleX / 128
		$AngleYTemp = $AngleY / 128
		$AngleZTemp = $AngleZ / 128

		$CosX = [System.Math]::Cos($AngleXTemp)
		$SinX = [System.Math]::Sin($AngleXTemp)

		$CosY = [System.Math]::Cos($AngleYTemp)
		$SinY = [System.Math]::Sin($AngleYTemp)

		$CosZ = [System.Math]::Cos($AngleZTemp)
		$SinZ = [System.Math]::Sin($AngleZTemp)

		For ($i=0; $i -le $VectorBallsNum; $i++)
		{
			# x-rotation
    		$z2 = $VectorBallsDefY[$i] * $SinX + $VectorBallsDefZ[$i] * $CosX

			# y-rotation
			$x3 = $VectorBallsDefX[$i] * $CosY + $z2 * $SinY
    		$y3 = $VectorBallsDefY[$i] * $CosX - $VectorBallsDefZ[$i] * $SinX

			# z-rotation and into array
    		$VectorBallsCoordX[$i] = $x3 * $CosZ - $y3 * $SinZ
    		$VectorBallsCoordY[$i] = $x3 * $SinZ + $y3 * $CosZ
    		$VectorBallsCoordZ[$i] = -$VectorBallsDefX[$i] * $SinY + $z2 * $CosY
  		}

		# Selection sort of z/depth
		For ($i=0; $i -le $VectorBallsNum; $i++)
		{
	       	$Min = $i
		    For ($j = $i + 1; $j -le $VectorBallsNum; ++$j)
			{
            	If ($VectorBallsCoordZ[$j] -lt $VectorBallsCoordZ[$Min])
				{
    	            $Min = $j
				}
			}

			$VectorBallsCoordX[$Min], $VectorBallsCoordX[$i] = $VectorBallsCoordX[$i], $VectorBallsCoordX[$Min]
        	$VectorBallsCoordY[$Min], $VectorBallsCoordY[$i] = $VectorBallsCoordY[$i], $VectorBallsCoordY[$Min]
        	$VectorBallsCoordZ[$Min], $VectorBallsCoordZ[$i] = $VectorBallsCoordZ[$i], $VectorBallsCoordZ[$Min]
		}

  		For ($i=0; $i -le $VectorBallsNum; $i++)
		{
    		$Factor = ($VectorBallsCoordZ[$i] + 15)
			$Buffer.DrawImage($VectorBallsBob, ($VectorBallsCoordX[$i] * 2 * $Factor + 220) + 150, ($VectorBallsCoordY[$i] * 2 * $Factor + 180) + 80, $Factor * 3, $Factor * 3)
		}

  		$AngleX += 5
		$AngleY += 4
		$AngleZ += 3

		ComposeScreen($false)
	} Until ($Timer -ge $StopTime)

	$VectorBallsBob.Dispose()
}


# Parallax Starfield, Landscape
Function Landscape($Runtime)
{
	$StopTime = [System.Environment]::TickCount + $Runtime

	# Init Landscape
	Set-Variable LandscapeWidth -Option Constant -Value 800
	Set-Variable LandscapeHeight -Option Constant -Value 295
	Set-Variable LandscapeTextureSize -Option Constant -Value 127
	Set-Variable LandscapeHalfX -Option Constant -Value ($LandscapeWidth -shr 1)
	Set-Variable LandscapeHalfY -Option Constant -Value ($LandscapeHeight -shr 1)
	Set-Variable YPos -Option Constant -Value 40
	Set-Variable XOrigin -Option Constant -Value 64
	Set-Variable ZOrigin -Option Constant -Value 64
	$Landscapegfx 			= New-Object $Chunky($BufferBMP)
	$LandIMG			 	= [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\Landscape.png")
	$LandscapeTextureIMG	= [System.Drawing.Image]::Fromfile($localScriptRoot + "\GFX\LandscapeTexture.png")
	$LandscapeBrush		 	= New-Object Drawing.SolidBrush ("Black")
	$LandscapeAngle 		= 0

	# Lock terrain & texture maps
	$LandscapeTextureMap = New-Object $Chunky($LandscapeTextureIMG)
	$LandscapeTerrainMap = New-Object $Chunky($LandIMG)

	$LandscapeTextureMap.Lock()
	$LandscapeTerrainMap.Lock()

	Do
	{
		$Buffer.Clear($ClearColor)

		ParallaxStarfield

		$Buffer.FillRectangle($LandscapeBrush,0,150,$MainWindowWidth,295)

		#Landscape
		$Landscapegfx.Lock()

		$LandscapeAngle += 10

		If ($LandscapeAngle -gt 627) 
		{
			$LandscapeAngle = 0
		}

		$LandscapeAngleTemp = $LandscapeAngle * 0.01
		$XPos = 63 + (([int]([System.Math]::Cos($LandscapeAngleTemp) * 128) -shl 7) -shr 7)
		$ZPos = 63 + (([int]([System.Math]::Sin($LandscapeAngleTemp) * 128) -shl 7) -shr 7)

		If ($ZOrigin - $ZPos -gt 0)
		{
			$Factor = 100 * ([System.Math]::Atan([single]($XOrigin - $XPos) / ($ZOrigin - $ZPos)))
		}
		Else
		{
			$Factor = 100 * ($PI + [System.Math]::Atan([single]($XOrigin - $XPos) / ($ZOrigin - $ZPos)))
		}

		$FactorTemp = $Factor * 0.01
		$CosA = [int]([System.Math]::Cos($FactorTemp) * 128)
		$SinA = [int]([System.Math]::Sin($FactorTemp) * 128)

		For ($x=0; $x -le $LandscapeTextureSize; $x++)
 		{
  			For ($z=0; $z -le $LandscapeTextureSize; $z++)
    		{
				$tempX = (($x - $XPos) * $CosA - ($z - $ZPos) * $SinA)
    			$tempY = (($LandscapeTerrainMap.GetPixel($x,$z).R) -shr 2) - $YPos
    			$tempZ = (($x - $XPos) * $SinA + ($z - $ZPos) * $CosA) -shr 7

				# 3D to 2D transformation and draw pixel
				$Landscapegfx.SetPixel(($LandscapeHalfX + ($tempX -shl 2) / $tempZ),($LandscapeHalfY - ($tempY -shl 7) / $tempZ) + 150, $LandscapeTextureMap.GetPixel($x,$z))
			}
		}

		$Landscapegfx.Release()

		ComposeScreen($true)

	} Until ($Timer -ge $StopTime)

	$LandscapeTextureMap.Release()
	$LandscapeTerrainMap.Release()

	$LandIMG.Dispose()
	$LandscapeTextureIMG.Dispose()
}

#endregion

#region Start Demo

$MainWindow.Show()

IntroText

# Mainloop

while ($true)
{
	Rasterbars($PartsRuntime)				# Parallax Starfield, Rasterbars & Bouncing Logo
	Plasma($PartsRuntime)					# 3D Starfield, Plasma
	SineScroller($PartsRuntime)				# Parallax Starfield, Bobs and SineScroller
	FilledVectorCube($PartsRuntime)			# 3D Starfield and FilledVectorCube
	Fire($PartsRuntime)						# Parallax Starfield, Fire
	Rotozoomer($PartsRuntime)				# 3D Starfield and RotoZoomer
	Metaballs($PartsRuntime)				# Parallax Starfield, Metaballs 2D
	Tunnel($PartsRuntime)					# 3D Starfield, Tunnel
	Landscape($PartsRuntime)				# Parallax Starfield, Landscape
	VectorBalls($PartsRuntime)				# 3D Starfield, Vectorballs
	DotTunnel($PartsRuntime)				# Parallax Starfield, DotTunnel
}

#endregion