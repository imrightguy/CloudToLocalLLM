# Zoidbot User Guide

This guide will help you get the most out of Zoidbot, covering all major features and functionality.

## Contents

1. [Getting Started](#getting-started)
2. [Interface Overview](#interface-overview)
3. [Conversations](#conversations)
4. [LLM Models](#llm-models)
5. [Settings](#settings)
6. [Cloud Synchronization](#cloud-synchronization)
7. [Remote Access](#remote-access)
8. [Troubleshooting](#troubleshooting)

## Getting Started

After [installing the application](SETUP_GUIDE.md), launch Zoidbot. The first time you run it, you'll be taken to the home screen, which displays a welcome message and prompts you to start a new conversation.

## Interface Overview

The Zoidbot interface consists of several main components:

### Main Navigation

- **Home Screen**: Displays your conversations
- **Models Screen**: Manage your LLM models
- **Settings Screen**: Configure application settings
- **Account**: Access login and account settings

### Drawer Menu

Access the drawer by clicking the hamburger icon (≡) in the top-left corner. The drawer provides:

- **Conversations List**: View and manage your conversations
- **Create New Conversation**: Start a new chat
- **Models**: Access the Models screen
- **Settings**: Access application settings
- **Login/Logout**: Account management

## Conversations

### Creating a New Conversation

1. Click the "+" floating action button on the home screen, or
2. Select "New Conversation" from the drawer menu

### Managing Conversations

- **Select a Conversation**: Click on it in the drawer menu
- **Delete a Conversation**: Click the trash icon next to the conversation in the drawer
- **Rename a Conversation**: Available in settings menu (right-click conversation)

### Chat Interface

- **Message Input**: Type your message at the bottom of the screen
- **Send Button**: Click to send your message
- **Message History**: View the conversation history in the main area
- **Model Selection**: Change the model using the dropdown in the app bar

## LLM Models

### Viewing Available Models

1. Go to the Models screen from the drawer menu
2. View installed and available models

### Managing Models

- **Download a Model**: Click "Pull" next to a model to download it
- **Delete a Model**: Click the trash icon next to a model to remove it
- **View Model Info**: Click on a model to view additional information

## Settings

### LLM Provider Settings

- **Provider Selection**: Choose between Ollama and LM Studio
- **IP Address Settings**: Configure connection details for each provider
- **Offline Mode**: Enable/disable to work without internet connection

### Appearance Settings

- **Theme Selection**: Choose between Light, Dark, or System themes

### Cloud Settings

- **Cloud Sync**: Enable/disable synchronization with cloud
- **Remote Access**: Enable/disable tunnel for remote access

## Cloud Synchronization

Cloud synchronization allows you to back up and access your conversations across multiple devices.

### Setting Up Cloud Sync

1. Create an account or log in to an existing account
2. In Settings, enable "Cloud Sync"
3. Your conversations will automatically synchronize when changes are made

### Privacy Note

Only encrypted data is sent to the cloud. Your local LLM interactions remain private unless you enable remote access.

## Remote Access

Remote access allows you to access your local LLM from other devices or share access with others.

### Setting Up Remote Access

1. Log in to your account
2. In Settings, enable "Remote Access"
3. Note the provided access URL

### Tunnel Status

- **Connected**: Your LLM is accessible remotely
- **Disconnected**: Remote access is currently disabled
- **Check Status**: Click the button to verify the connection

### Security Considerations

- Remote access requires authentication
- Access is only available while the application is running
- Consider firewall settings if you encounter connection issues

## Troubleshooting

For common issues and solutions, please refer to the [Troubleshooting Guide](TROUBLESHOOTING.md).

### Getting Help

If you encounter persistent issues:

1. Check [GitHub Issues](https://github.com/your-username/Zoidbot/issues) for similar problems
2. Join our community discussion (link in README)
3. Open a new issue with detailed information about your problem
