# Azure Pipeline Build: VM Deployment and Configuration

This repository provides an automated pipeline for creating and configuring virtual machines (VM) on Azure using Azure Pipelines.

## Overview

The pipeline consists of multiple stages, including:
1. **VM Creation**: Automates the process of VM creation in Azure.
2. **Azure Configuration**: Configures the Azure resources based on the provided parameters.
3. **VM Preparation**: Prepares the VM with pre-configuration settings.
4. **VM Server Configuration**: Sets up server-specific configurations on the VM.
5. **Software Installation**: Installs necessary software on the VM.

## Parameters

The pipeline accepts the following parameters:

- **userPublicIp**: The public IP of the user. This is used during the Azure Configuration phase.

## Stages

### 1. VM Creation

#### Jobs:
- **Create_VM**: Automates the creation of the virtual machine.
  - **Steps**:
    - Uninstall AzureRM Module.
    - Install/Update the latest version of the Az Module.
    - Create a VM using the provided `create_vm.ps1` PowerShell script.

### 2. Azure Configuration

#### Jobs:
- **Configure_Azure**: Sets up Azure resources.
  - **Steps**:
    - Uninstall AzureRM Module.
    - Install/Update the latest version of the Az Module.
    - Configure Azure resources using the provided `configure_azure.ps1` PowerShell script.

### 3. VM Preparation

#### Jobs:
- **Prepare_VM**: Prepares the virtual machine.
  - **Steps**:
    - Execute the `vm_preparation.ps1` PowerShell script on the VM using the Azure CLI.

### 4. VM Server Configuration

#### Jobs:
- **Server_Config_VM**: Applies server-specific configurations to the VM.
  - **Steps**:
    - Execute the `vm_server_config.ps1` PowerShell script on the VM using the Azure CLI.

### 5. Software Installation

#### Jobs:
- **Install_Software_VM**: Installs software on the virtual machine.
  - **Steps**:
    - Execute the `vm_software_install.ps1` PowerShell script on the VM using the Azure CLI.

## Usage

To use this pipeline, set up an Azure Pipelines environment and provide the required parameters. Ensure that you have all the necessary scripts (`create_vm.ps1`, `configure_azure.ps1`, `vm_preparation.ps1`, `vm_server_config.ps1`, `vm_software_install.ps1`) in your repository.

Ensure that you have the necessary permissions in Azure to create and manage resources, especially VMs.
