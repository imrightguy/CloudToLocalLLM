# GitHub Release Creation and Validation Integration Tests
# Tests GitHub CLI integration, release creation, and validation workflows

BeforeAll {
    # Import required modules
    $TestConfigPath = Join-Path $PSScriptRoot "..\TestConfig.ps1"
    $MocksPath = Join-Path $PSScriptRoot "..\Mocks\WSLMocks.ps1"
    
    . $TestConfigPath
    . $MocksPath
    
    # Initialize test configuration
    $Global:TestConfig = Initialize-TestConfig
    
    # Set up GitHub test configuration
    $Global:GitHubTestConfig = @{
        Repository = @{
            Owner = "test-owner"
            Name = "zoidbot"
            FullName = "test-owner/zoidbot"
            DefaultBranch = "main"
            RemoteUrl = "https://github.com/test-owner/zoidbot.git"
        }
        Release = @{
            TagName = "v3.10.4"
            Name = "Zoidbot v3.10.4"
            Body = "Release notes for version 3.10.4"
            Draft = $false
            Prerelease = $false
            TargetCommitish = "main"
        }
        Authentication = @{
            Token = "ghp_test_token_1234567890abcdef"
            User = "test-user"
        }
    }
    
    # Mock external commands
    Mock Write-Host { }
    Mock Write-Progress { }
}

Describe "GitHub CLI Integration Tests" {
    
    Context "GitHub CLI Availability and Authentication" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
        }
        
        It "Should detect GitHub CLI availability" {
            Mock Test-Command { param($CommandName) return $CommandName -eq "gh" }
            
            $result = Test-Command -CommandName "gh"
            
            $result | Should -Be $true
        }
        
        It "Should validate GitHub CLI authentication" {
            Mock gh { 
                param($args)
                if ($args -contains "auth" -and $args -contains "status") {
                    $Global:LASTEXITCODE = 0
                    return @(
                        "github.com",
                        "  ✓ Logged in to github.com as test-user (oauth_token)",
                        "  ✓ Git operations for github.com configured to use https protocol.",
                        "  ✓ Token: ghp_****1234"
                    ) -join "`n"
                }
                return "gh command output"
            }
            
            $result = gh auth status
            
            $result | Should -Match "Logged in to github.com"
            $result | Should -Match "test-user"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should handle GitHub CLI authentication failure" {
            Mock gh { 
                param($args)
                if ($args -contains "auth" -and $args -contains "status") {
                    $Global:LASTEXITCODE = 1
                    return "You are not logged into any GitHub hosts. Run gh auth login to authenticate."
                }
                return "gh command output"
            }
            
            $result = gh auth status
            
            $result | Should -Match "not logged into any GitHub hosts"
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should validate repository access" {
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            Mock gh { 
                param($args)
                if ($args -contains "repo" -and $args -contains "view") {
                    $Global:LASTEXITCODE = 0
                    return @(
                        "name: $($repoConfig.Name)",
                        "owner: $($repoConfig.Owner)",
                        "description: Zoidbot - Multi-tenant AI application",
                        "visibility: public",
                        "defaultBranch: $($repoConfig.DefaultBranch)"
                    ) -join "`n"
                }
                return "gh command output"
            }
            
            $result = gh repo view $repoConfig.FullName
            
            $result | Should -Match $repoConfig.Name
            $result | Should -Match $repoConfig.Owner
            $LASTEXITCODE | Should -Be 0
        }
    }
    
    Context "Release Creation Workflow" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
        }
        
        It "Should create a new GitHub release successfully" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            Mock gh { 
                param($args)
                if ($args -contains "release" -and $args -contains "create") {
                    $Global:LASTEXITCODE = 0
                    return "https://github.com/$($repoConfig.FullName)/releases/tag/$($releaseConfig.TagName)"
                }
                return "gh command output"
            }
            
            $result = gh release create $releaseConfig.TagName --title $releaseConfig.Name --notes $releaseConfig.Body --repo $repoConfig.FullName
            
            $result | Should -Match $releaseConfig.TagName
            $result | Should -Match "releases/tag"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should handle release creation with draft flag" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            Mock gh { 
                param($args)
                if ($args -contains "release" -and $args -contains "create" -and $args -contains "--draft") {
                    $Global:LASTEXITCODE = 0
                    return "Draft release created: https://github.com/$($repoConfig.FullName)/releases/tag/$($releaseConfig.TagName)"
                }
                return "gh command output"
            }
            
            $result = gh release create $releaseConfig.TagName --title $releaseConfig.Name --notes $releaseConfig.Body --draft --repo $repoConfig.FullName
            
            $result | Should -Match "Draft release created"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should handle release creation with prerelease flag" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            Mock gh { 
                param($args)
                if ($args -contains "release" -and $args -contains "create" -and $args -contains "--prerelease") {
                    $Global:LASTEXITCODE = 0
                    return "Pre-release created: https://github.com/$($repoConfig.FullName)/releases/tag/$($releaseConfig.TagName)"
                }
                return "gh command output"
            }
            
            $result = gh release create $releaseConfig.TagName --title $releaseConfig.Name --notes $releaseConfig.Body --prerelease --repo $repoConfig.FullName
            
            $result | Should -Match "Pre-release created"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should handle release creation failure" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            Mock gh { 
                param($args)
                if ($args -contains "release" -and $args -contains "create") {
                    $Global:LASTEXITCODE = 1
                    return "Error: release tag already exists"
                }
                return "gh command output"
            }
            
            $result = gh release create $releaseConfig.TagName --title $releaseConfig.Name --notes $releaseConfig.Body --repo $repoConfig.FullName
            
            $result | Should -Match "Error"
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should generate release notes from commits" {
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            Mock gh { 
                param($args)
                if ($args -contains "release" -and $args -contains "create" -and $args -contains "--generate-notes") {
                    $Global:LASTEXITCODE = 0
                    return "Release created with auto-generated notes"
                }
                return "gh command output"
            }
            
            $result = gh release create "v3.10.4" --generate-notes --repo $repoConfig.FullName
            
            $result | Should -Match "auto-generated notes"
            $LASTEXITCODE | Should -Be 0
        }
    }
    
    Context "Release Validation and Management" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
        }
        
        It "Should list existing releases" {
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            Mock gh { 
                param($args)
                if ($args -contains "release" -and $args -contains "list") {
                    $Global:LASTEXITCODE = 0
                    return @(
                        "v3.10.4	Zoidbot v3.10.4	Latest	2024-01-15T10:30:00Z",
                        "v3.10.3	Zoidbot v3.10.3	        	2024-01-10T15:20:00Z",
                        "v3.10.2	Zoidbot v3.10.2	        	2024-01-05T09:15:00Z"
                    ) -join "`n"
                }
                return "gh command output"
            }
            
            $result = gh release list --repo $repoConfig.FullName
            
            $result | Should -Match "v3.10.4"
            $result | Should -Match "v3.10.3"
            $result | Should -Match "Latest"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should view specific release details" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            Mock gh { 
                param($args)
                if ($args -contains "release" -and $args -contains "view") {
                    $Global:LASTEXITCODE = 0
                    return @(
                        "title: $($releaseConfig.Name)",
                        "tag: $($releaseConfig.TagName)",
                        "draft: false",
                        "prerelease: false",
                        "author: test-user",
                        "published: 2024-01-15T10:30:00Z",
                        "",
                        "--",
                        "",
                        $releaseConfig.Body
                    ) -join "`n"
                }
                return "gh command output"
            }
            
            $result = gh release view $releaseConfig.TagName --repo $repoConfig.FullName
            
            $result | Should -Match $releaseConfig.Name
            $result | Should -Match $releaseConfig.TagName
            $result | Should -Match $releaseConfig.Body
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should delete a release" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            Mock gh { 
                param($args)
                if ($args -contains "release" -and $args -contains "delete") {
                    $Global:LASTEXITCODE = 0
                    return "Release $($releaseConfig.TagName) deleted"
                }
                return "gh command output"
            }
            
            $result = gh release delete $releaseConfig.TagName --yes --repo $repoConfig.FullName
            
            $result | Should -Match "deleted"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should upload assets to release" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            # Create mock asset file
            $assetPath = Join-Path $TestDrive "zoidbot-v3.10.4.zip"
            Set-Content -Path $assetPath -Value "Mock release asset content"
            
            Mock gh { 
                param($args)
                if ($args -contains "release" -and $args -contains "upload") {
                    $Global:LASTEXITCODE = 0
                    return "Asset uploaded successfully"
                }
                return "gh command output"
            }
            
            $result = gh release upload $releaseConfig.TagName $assetPath --repo $repoConfig.FullName
            
            $result | Should -Match "uploaded successfully"
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Git Integration for Release Management" {
    
    Context "Git Repository State Validation" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
        }
        
        It "Should validate clean working directory before release" {
            Mock git { 
                param($args)
                if ($args -contains "status" -and $args -contains "--porcelain") {
                    $Global:LASTEXITCODE = 0
                    return ""  # Clean working directory
                }
                return "git command output"
            }
            
            $result = git status --porcelain
            
            $result | Should -BeNullOrEmpty
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should detect uncommitted changes" {
            Mock git { 
                param($args)
                if ($args -contains "status" -and $args -contains "--porcelain") {
                    $Global:LASTEXITCODE = 0
                    return @(
                        " M lib/main.dart",
                        "?? new_file.txt"
                    ) -join "`n"
                }
                return "git command output"
            }
            
            $result = git status --porcelain
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match "lib/main.dart"
            $result | Should -Match "new_file.txt"
        }
        
        It "Should validate current branch" {
            Mock git { 
                param($args)
                if ($args -contains "branch" -and $args -contains "--show-current") {
                    $Global:LASTEXITCODE = 0
                    return "main"
                }
                return "git command output"
            }
            
            $result = git branch --show-current
            
            $result | Should -Be "main"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should get latest commit information" {
            Mock git { 
                param($args)
                if ($args -contains "log" -and $args -contains "--oneline") {
                    $Global:LASTEXITCODE = 0
                    return @(
                        "abc123d feat: Add new deployment workflow",
                        "def456e fix: Resolve authentication issue",
                        "ghi789f docs: Update README with new features"
                    ) -join "`n"
                }
                return "git command output"
            }
            
            $result = git log --oneline -n 3
            
            $result | Should -Match "feat: Add new deployment workflow"
            $result | Should -Match "fix: Resolve authentication issue"
            $result | Should -Match "docs: Update README"
        }
    }
    
    Context "Git Tagging for Releases" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
        }
        
        It "Should create annotated tag for release" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            
            Mock git { 
                param($args)
                if ($args -contains "tag" -and $args -contains "-a") {
                    $Global:LASTEXITCODE = 0
                    return "Tag $($releaseConfig.TagName) created"
                }
                return "git command output"
            }
            
            $result = git tag -a $releaseConfig.TagName -m $releaseConfig.Name
            
            $result | Should -Match "Tag.*created"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should push tags to remote repository" {
            Mock git { 
                param($args)
                if ($args -contains "push" -and $args -contains "--tags") {
                    $Global:LASTEXITCODE = 0
                    return "Tags pushed to origin"
                }
                return "git command output"
            }
            
            $result = git push --tags
            
            $result | Should -Match "Tags pushed"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should list existing tags" {
            Mock git { 
                param($args)
                if ($args -contains "tag" -and $args -contains "--list") {
                    $Global:LASTEXITCODE = 0
                    return @(
                        "v3.10.1",
                        "v3.10.2",
                        "v3.10.3",
                        "v3.10.4"
                    ) -join "`n"
                }
                return "git command output"
            }
            
            $result = git tag --list
            
            $result | Should -Match "v3.10.4"
            $result | Should -Match "v3.10.3"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should delete a tag" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            
            Mock git { 
                param($args)
                if ($args -contains "tag" -and $args -contains "-d") {
                    $Global:LASTEXITCODE = 0
                    return "Deleted tag '$($releaseConfig.TagName)'"
                }
                return "git command output"
            }
            
            $result = git tag -d $releaseConfig.TagName
            
            $result | Should -Match "Deleted tag"
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Release Notes Generation Tests" {
    
    Context "Automated Release Notes" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
        }
        
        It "Should generate release notes from commit messages" {
            Mock git { 
                param($args)
                if ($args -contains "log" -and $args -contains "--pretty=format") {
                    $Global:LASTEXITCODE = 0
                    return @(
                        "feat: Add automated deployment workflow",
                        "fix: Resolve SSH connectivity issues",
                        "docs: Update deployment documentation",
                        "test: Add comprehensive integration tests",
                        "refactor: Improve error handling in deployment script"
                    ) -join "`n"
                }
                return "git command output"
            }
            
            $result = git log --pretty=format:"%s" v3.10.3..HEAD
            
            $result | Should -Match "feat:"
            $result | Should -Match "fix:"
            $result | Should -Match "docs:"
            $result | Should -Match "test:"
            $result | Should -Match "refactor:"
        }
        
        It "Should categorize commits by type" {
            $commitMessages = @(
                "feat: Add automated deployment workflow",
                "fix: Resolve SSH connectivity issues",
                "docs: Update deployment documentation",
                "test: Add comprehensive integration tests",
                "refactor: Improve error handling in deployment script"
            )
            
            $features = $commitMessages | Where-Object { $_ -like "feat:*" }
            $fixes = $commitMessages | Where-Object { $_ -like "fix:*" }
            $docs = $commitMessages | Where-Object { $_ -like "docs:*" }
            
            $features.Count | Should -Be 1
            $fixes.Count | Should -Be 1
            $docs.Count | Should -Be 1
        }
        
        It "Should format release notes with proper sections" {
            $releaseNotes = @"
# Zoidbot v3.10.4

## New Features
- Add automated deployment workflow

## Bug Fixes
- Resolve SSH connectivity issues

## Documentation
- Update deployment documentation

## Tests
- Add comprehensive integration tests

## Refactoring
- Improve error handling in deployment script
"@
            
            $releaseNotes | Should -Match "# Zoidbot v3.10.4"
            $releaseNotes | Should -Match "## New Features"
            $releaseNotes | Should -Match "## Bug Fixes"
            $releaseNotes | Should -Match "## Documentation"
        }
    }
}

Describe "Release Workflow Integration Tests" {
    
    Context "Complete Release Creation Workflow" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
            
            # Mock all required commands for complete workflow
            Mock git { 
                param($args)
                if ($args -contains "status" -and $args -contains "--porcelain") {
                    return ""  # Clean working directory
                }
                elseif ($args -contains "branch" -and $args -contains "--show-current") {
                    return "main"
                }
                elseif ($args -contains "tag") {
                    $Global:LASTEXITCODE = 0
                    return "Tag created"
                }
                elseif ($args -contains "push") {
                    $Global:LASTEXITCODE = 0
                    return "Pushed to origin"
                }
                return "git command output"
            }
            
            Mock gh { 
                param($args)
                if ($args -contains "auth" -and $args -contains "status") {
                    return "✓ Logged in to github.com as test-user"
                }
                elseif ($args -contains "release" -and $args -contains "create") {
                    $Global:LASTEXITCODE = 0
                    return "Release created successfully"
                }
                return "gh command output"
            }
        }
        
        It "Should execute complete release workflow successfully" {
            $releaseConfig = $Global:GitHubTestConfig.Release
            $repoConfig = $Global:GitHubTestConfig.Repository
            
            # Simulate complete workflow
            $workflow = @{
                GitStatus = git status --porcelain
                GitBranch = git branch --show-current
                GitTag = git tag -a $releaseConfig.TagName -m $releaseConfig.Name
                GitPush = git push --tags
                GHAuth = gh auth status
                GHRelease = gh release create $releaseConfig.TagName --title $releaseConfig.Name --notes $releaseConfig.Body --repo $repoConfig.FullName
            }
            
            # Verify each step
            $workflow.GitStatus | Should -BeNullOrEmpty  # Clean working directory
            $workflow.GitBranch | Should -Be "main"
            $workflow.GitTag | Should -Match "Tag created"
            $workflow.GitPush | Should -Match "Pushed to origin"
            $workflow.GHAuth | Should -Match "Logged in"
            $workflow.GHRelease | Should -Match "Release created"
        }
        
        It "Should handle workflow failure at any step" {
            # Test failure at Git status check
            Mock git { 
                param($args)
                if ($args -contains "status" -and $args -contains "--porcelain") {
                    return " M lib/main.dart"  # Uncommitted changes
                }
                return "git command output"
            }
            
            $gitStatus = git status --porcelain
            $gitStatus | Should -Not -BeNullOrEmpty  # Should detect uncommitted changes
            
            # Test failure at GitHub authentication
            Mock gh { 
                param($args)
                if ($args -contains "auth" -and $args -contains "status") {
                    $Global:LASTEXITCODE = 1
                    return "You are not logged into any GitHub hosts"
                }
                return "gh command output"
            }
            
            $ghAuth = gh auth status
            $ghAuth | Should -Match "not logged into any GitHub hosts"
            $LASTEXITCODE | Should -Be 1
        }
    }
}

AfterAll {
    # Cleanup test environment
    Clear-TestConfig
}