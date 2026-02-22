#!/bin/bash

echo "Starting macOS setup script..."

# 1. Install Homebrew if not already installed
if ! command -v brew &> /dev/null
then
    echo "Homebrew not found, installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew is already installed."
fi

# 2. Install packages and casks from Brewfile
echo "Installing packages from Brewfile..."
brew bundle --file="$(dirname "$0")/Brewfile"

# 3. Install Go via official tarball
if command -v go &> /dev/null; then
    echo "Go is already installed: $(go version)."
    read -p "Do you want to reinstall/change version? (y/N): " reinstall_go
    if [[ ! "$reinstall_go" =~ ^[Yy]$ ]]; then
        echo "Keeping current Go installation."
    fi
fi

if ! command -v go &> /dev/null || [[ "$reinstall_go" =~ ^[Yy]$ ]]; then
    echo "Fetching available Go versions..."

    # Detect architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        GO_ARCH="arm64"
    elif [ "$ARCH" = "x86_64" ]; then
        GO_ARCH="amd64"
    else
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
    fi

    # Fetch stable versions from go.dev JSON API
    GO_VERSIONS=$(curl -fsSL "https://go.dev/dl/?mode=json&include=all" \
        | grep -o '"version":"go[0-9.]*"' \
        | head -10 \
        | sed 's/"version":"//;s/"//')

    echo ""
    echo "Available Go versions:"
    i=1
    while IFS= read -r ver; do
        if [ $i -eq 1 ]; then
            echo "  $i) $ver (latest)"
        else
            echo "  $i) $ver"
        fi
        i=$((i + 1))
    done <<< "$GO_VERSIONS"

    echo ""
    read -p "Select a version [1]: " version_choice
    version_choice=${version_choice:-1}

    GO_VERSION=$(echo "$GO_VERSIONS" | sed -n "${version_choice}p")
    if [ -z "$GO_VERSION" ]; then
        echo "ERROR: Invalid selection."
        exit 1
    fi

    echo "Installing $GO_VERSION..."

    GO_TARBALL="${GO_VERSION}.darwin-${GO_ARCH}.tar.gz"
    GO_URL="https://go.dev/dl/${GO_TARBALL}"

    echo "Downloading $GO_URL..."
    curl -fsSL -o "/tmp/${GO_TARBALL}" "$GO_URL"

    echo "Extracting to /usr/local/go..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
    rm "/tmp/${GO_TARBALL}"

    echo "Go installed successfully: $(/usr/local/go/bin/go version)"
fi

# 4. Install Go tools
echo "Installing Go tools..."
/usr/local/go/bin/go install golang.org/x/tools/cmd/goimports@latest
/usr/local/go/bin/go install golang.org/x/tools/gopls@latest
/usr/local/go/bin/go install github.com/go-delve/delve/cmd/dlv@latest

# 5. Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh not found, installing..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh is already installed."
fi

# 6. Copy dotfiles
echo "Copying dotfiles..."
cp -v "$(dirname "$0")/dotfiles/zshrc" "$HOME/.zshrc"
cp -v "$(dirname "$0")/dotfiles/gitconfig" "$HOME/.gitconfig"
# Special handling for iTerm2 preferences (requires manual import)
cp -v "$(dirname "$0")/dotfiles/com.googlecode.iterm2.plist" "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
# Cursor settings
mkdir -p "$HOME/Library/Application Support/Cursor/User/"
cp -v "$(dirname "$0")/dotfiles/settings.json" "$HOME/Library/Application Support/Cursor/User/settings.json"

echo "Dotfiles copied. Please restart your terminal for .zshrc changes to take effect."
echo "For iTerm2 settings, you may need to manually import the 'com.googlecode.iterm2.plist' file."

# 7. Install Claude Code
echo "Installing Claude Code..."
if command -v npm &> /dev/null; then
    sudo npm install -g @anthropic-ai/claude-code
else
    echo "WARNING: npm not found. Skipping Claude Code installation."
fi

# 8. Install Extensions
echo "Installing Monokai Pro extension..."
if command -v code &> /dev/null; then
    code --install-extension monokai-pro-vscode
fi
if command -v cursor &> /dev/null; then
    cursor --install-extension monokai-pro-vscode
fi

# 9. Generate SSH key for GitHub
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Generating SSH key for GitHub..."
    read -p "Enter your GitHub email: " github_email
    ssh-keygen -t ed25519 -C "$github_email" -f "$HOME/.ssh/id_ed25519"
    eval "$(ssh-agent -s)"

    # Create SSH config if it doesn't exist
    if [ ! -f "$HOME/.ssh/config" ]; then
        cat <<EOF > "$HOME/.ssh/config"
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
    fi

    ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519"

    # Copy public key to clipboard
    pbcopy < "$HOME/.ssh/id_ed25519.pub"
    echo "SSH public key copied to clipboard! Add it to GitHub at https://github.com/settings/keys"
    read -p "Press Enter after you've added the key to GitHub..."

    # Test the connection
    ssh -T git@github.com
else
    echo "SSH key already exists at ~/.ssh/id_ed25519, skipping generation."
fi

# 10. Set up Google Cloud SDK (uncomment when needed)
# echo "Setting up Google Cloud SDK..."
# if command -v gcloud &> /dev/null; then
#     echo "Google Cloud SDK found. Running 'gcloud init'..."
#     gcloud init
# else
#     # Source gcloud from Homebrew if not yet on PATH
#     if [ -f "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc" ]; then
#         source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
#         source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"
#         echo "Google Cloud SDK sourced. Running 'gcloud init'..."
#         gcloud init
#     else
#         echo "WARNING: Google Cloud SDK not found. Please install it and run 'gcloud init' manually."
#     fi
# fi

echo "Setup script finished!"
