# Neuro MXC OpenClaw Azure Sandbox

Deploy **OpenClaw** on **Azure** in one Terraform apply: a Windows 11 VM with **Microsoft Execution Containers (MXC)** sandboxing for safer AI agent tool execution.

**NeuroGamingLab**

---

## Architecture

Enforcing physical boundaries via MXC and OpenClaw

OpenClaw runs inside MXC containers on Windows. Multi-step agent actions are constrained by **OS-enforced boundaries**, reducing unrestricted access to the host session. Developers and IT administrators define boundary rules through MXC’s policy-driven profiles.


| Layer                | Role                                                                |
| -------------------- | ------------------------------------------------------------------- |
| **OpenClaw**         | Open-source AI agent runtime (gateway, tools, channels)             |
| **MXC**              | Policy-driven, OS-level sandbox for untrusted code / tool execution |
| **Windows 11 24H2+** | Required host OS for MXC client backends                            |
| **Azure VM**         | Terraform-provisioned compute in `canadacentral` (configurable)     |


---

## What is Microsoft MXC?

**MXC (Microsoft Execution Containers)** is a policy-driven, OS-level sandbox for running AI agents and untrusted code. It was announced at **Microsoft Build 2026** (June 2, 2026).

- **SDK:** `[@microsoft/mxc-sdk](https://www.npmjs.com/package/@microsoft/mxc-sdk)` (TypeScript); native runtime in [microsoft/mxc](https://github.com/microsoft/mxc)
- **Status:** Early preview (schema ~`0.6.0-alpha`) — **do not treat MXC profiles as production security boundaries yet**
- **Requirements:** Windows 11 Enterprise 24H2+ (build 26100+); Windows Server is **not** supported for client-only MXC backends

### Integration with OpenClaw

[OpenClaw](https://github.com/openclaw/openclaw) is an MXC launch partner. In this project:

- **OpenClaw** runs the agent and gateway
- **MXC** sandboxes the agent’s tool and code execution via the `processcontainer` backend (stable, no nested virtualization required)

---

## What this repo deploys


| Resource  | Default                                                          |
| --------- | ---------------------------------------------------------------- |
| Region    | `canadacentral`                                                  |
| OS        | Windows 11 Enterprise 24H2                                       |
| VM size   | `Standard_D4s_v3` (adjust for your quota)                        |
| Runtime   | Node 24, `@microsoft/mxc-sdk`, OpenClaw                          |
| Network   | Public IP, NSG rules for RDP (3389) and OpenClaw gateway (18789) |
| Bootstrap | Custom Script Extension installs and configures the gateway      |


---

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az login`)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- Azure subscription that can deploy **Windows 11 Enterprise** images (Dev/Test, AVD licensing, or equivalent)
- AI provider API key (OpenAI, Anthropic, etc.) for OpenClaw

---

## Quick start

```bash
git clone https://github.com/NeuroGamingLab/Neuro-MXC-OpenClaw-AzureSandbox.git
cd Neuro-MXC-OpenClaw-AzureSandbox/terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set admin_password and restrict allowed_rdp_cidr / allowed_gateway_cidr

az login
terraform init
terraform plan
terraform apply
```

After apply:

```bash
terraform output
```

---

## Accessing the VM and OpenClaw

### RDP (macOS)

1. Install **Microsoft Remote Desktop** from the Mac App Store
2. Connect to `terraform output -raw vm_public_ip` as `azureuser` with your `admin_password`

### OpenClaw gateway

On the VM:

1. Read `C:\openclaw\gateway-access.txt` for the gateway URL and token
2. Add `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` to `C:\openclaw\config\.env`
3. Restart: `powershell -File C:\openclaw\start-gateway.ps1 -Restart`

From your browser, open the gateway URL (default port **18789**) and paste the gateway token.

If you see **“Browser origin not allowed”**, add your origin to `gateway.controlUi.allowedOrigins` in `C:\openclaw\config\openclaw.json`, then restart the gateway. Example:

```json
"controlUi": {
  "allowedOrigins": [
    "http://localhost:18789",
    "http://127.0.0.1:18789",
    "http://YOUR_VM_PUBLIC_IP:18789"
  ]
}
```

---

## Project layout

```
.
├── image.png                 # Architecture diagram
├── instructions.txt          # Original design brief
├── scripts/
│   └── bootstrap.ps1         # VM bootstrap (Node, MXC SDK, OpenClaw gateway)
└── terraform/
    ├── main.tf
    ├── network.tf
    ├── storage.tf
    ├── vm.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars.example
```

---

## Security notes

This is a **lab / sandbox** template, not production-hardened:

- Restrict `allowed_rdp_cidr` and `allowed_gateway_cidr` to your IP — avoid `0.0.0.0/0` on the public internet
- Never commit `terraform.tfvars` or `terraform.tfstate` (they contain secrets)
- MXC is alpha preview; pin SDK versions and follow [microsoft/mxc](https://github.com/microsoft/mxc) guidance
- Rotate VM password and OpenClaw gateway token if exposed

---

## References

- [OpenClaw](https://github.com/openclaw/openclaw)
- [OpenClaw Gateway docs](https://docs.openclaw.ai/gateway)
- [Microsoft MXC](https://github.com/microsoft/mxc)
- [@microsoft/mxc-sdk on npm](https://www.npmjs.com/package/@microsoft/mxc-sdk)

---

## License

See repository license. Third-party components (OpenClaw, MXC SDK, Azure images) are subject to their own terms.

---

Designed by Dang-Tue Hoang, AI/ML Engineer