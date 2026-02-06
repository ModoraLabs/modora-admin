# 🎮 Modora FiveM Integration Resource

**Version:** 2.0.0  
**FiveM:** All versions  
**Author:** Modora Labs

---

## 📋 Overview

This FiveM resource connects your server to Modora Discord bot via a simple API integration. Players can create reports in-game that automatically become Discord tickets.

### Features

- ✅ `/report` command with native form interface
- ✅ Direct API integration with Modora Dashboard
- ✅ Simple API token authentication
- ✅ Custom form builder with categories and questions
- ✅ File upload support for attachments
- ✅ Nearby players detection
- ✅ Category-based ticket routing
- ✅ Multi-language support (Dutch/English)
- ✅ Automatic version checking via GitHub releases

---

## 🚀 Installation

### Step 1: Download & Install

1. Download or clone this resource from [GitHub](https://github.com/ModoraLabs/modora-reports)
2. Place the resource folder in your FiveM server's `resources` directory
3. Add to your `server.cfg`:
   ```cfg
   ensure modora-reports
   ```

### Step 2: Configure API Connection

1. Go to your Modora Dashboard
2. Navigate to: **Guild Settings > FiveM Integration**
3. Add a new server or select existing server
4. Copy the **API Token** from the server settings page
5. Edit `config.lua` and configure:
   ```lua
   -- API Base URL - Use http:// if you have SSL/TLS certificate issues
   -- Use https:// for production if your server supports it
   Config.ModoraAPIBase = 'http://api.modora.xyz'  -- or 'https://api.modora.xyz'
   Config.APIToken = 'your_api_token_here'
   ```

**HTTP vs HTTPS:**

**Current Situation:**
- ✅ **HTTPS works** (`curl https://api.modora.xyz/test` returns 200 OK)
- ❌ **HTTP redirects** (`curl http://api.modora.xyz/test` returns 307 redirect to HTTPS)
- ❌ **FiveM gets HTTP 0 errors** with HTTPS (SSL/TLS certificate issues)

**Two Solutions:**

**Solution 1: Use HTTPS (Recommended if it works)**
- Set `Config.ModoraAPIBase = 'https://api.modora.xyz'`
- If you get HTTP 0 errors, it's a FiveM SSL/TLS issue (see troubleshooting below)
- Try updating FiveM artifact version or CA certificates

**Solution 2: Use HTTP (Requires Cloudflare Configuration)**
- Set `Config.ModoraAPIBase = 'http://api.modora.xyz'`
- **MUST configure Cloudflare** to allow HTTP (see Cloudflare Configuration section below)
- Without Cloudflare config, HTTP will always redirect to HTTPS (307 error)

**⚠️ CRITICAL: Cloudflare Configuration (REQUIRED for HTTP to work)**

**If you see `HTTP/1.1 307 Temporary Redirect` when using `curl http://api.modora.xyz/test`, Cloudflare is redirecting HTTP to HTTPS!**

**Cloudflare blocks HTTP by default and redirects to HTTPS!** You MUST configure Cloudflare to allow HTTP, otherwise FiveM will get HTTP 0 errors.

**Why HTTP is needed:**
- FiveM's `PerformHttpRequest` has SSL/TLS certificate validation issues
- Even though `curl https://api.modora.xyz/test` works, FiveM cannot connect via HTTPS
- HTTP works in FiveM but requires Cloudflare configuration

**Step-by-Step Cloudflare Configuration:**

1. **Go to Cloudflare Dashboard** → Your Domain → **SSL/TLS**

2. **Find the subdomain `api.modora.xyz`** (or configure at domain level)

3. **Set SSL/TLS encryption mode to "Flexible"**:
   - This allows HTTP connections between Cloudflare and your origin server
   - **Important:** "Flexible" means Cloudflare → Visitor can be HTTPS, but Cloudflare → Origin can be HTTP
   - This is what we need for FiveM compatibility

4. **Alternative: Use Page Rules (if SSL/TLS mode doesn't work)**
   - Go to **Rules** → **Page Rules**
   - Create new rule: `api.modora.xyz/*`
   - Settings:
     - **SSL:** Set to **"Off"** or **"Flexible"**
     - **Always Use HTTPS:** **Off** (if present)
   - Save and deploy

5. **Alternative: Use Transform Rules (Most Control)**
   - Go to **Rules** → **Transform Rules** → **Modify Response Header**
   - Create rule matching: `http.host eq "api.modora.xyz"`
   - Action: Remove header `Location` if it contains `https://`
   - Or create a rule to disable HTTPS redirect

6. **Wait 1-2 minutes** for Cloudflare changes to propagate

7. **Test:**
   ```bash
   curl -I --http1.1 http://api.modora.xyz/test
   ```
   Should return `HTTP/1.1 200 OK` (NOT 307 redirect!)

**Troubleshooting:**
- If you still get 307 redirect: Clear Cloudflare cache or wait longer
- If SSL/TLS mode is "Full" or "Full (strict)": Change to "Flexible"
- Check if there are conflicting Page Rules or Transform Rules
- Verify the subdomain `api.modora.xyz` is actually proxied through Cloudflare (orange cloud)

**Note:** Without Cloudflare configuration, HTTP requests will ALWAYS be redirected to HTTPS (307), causing FiveM HTTP 0 errors!

### Step 3: Configure Additional Settings

Edit `config.lua` to customize:

```lua
Config.ReportCommand = 'report'        -- Command name
Config.ReportKeybind = 'F7'            -- Keybind (or false to disable)
Config.NearbyRadius = 30.0             -- Radius in meters for nearby players
Config.MaxNearbyPlayers = 5            -- Maximum number of nearby players to show
Config.Locale = 'nl'                   -- Language: 'nl' or 'en'
Config.Debug = false                   -- Set to true for detailed logging
```

### Step 4: Restart Resource

```
restart modora-reports
```

---

## 📖 Usage

### For Players

1. Type `/report` in chat or press `F7` (default keybind)
2. Fill in the report form
3. Click "Submit Report"
4. Report is automatically created as a Discord ticket
5. You'll receive confirmation with the ticket number in-game

### For Server Owners

1. **Configure Report Form in Dashboard:**
   - Go to: **Guild Settings > FiveM Integration > [Your Server]**
   - Use the **Report Form Builder** to create custom categories and questions
   - Assign ticket panels to specific categories

2. **Reports appear in your Discord ticket system:**
   - All player information is included
   - Custom form fields are displayed
   - Attachments are uploaded to Modora CDN

---

## ⚙️ Configuration Options

### `config.lua`

| Option | Description | Default |
|--------|-------------|---------|
| `Config.ModoraAPIBase` | API base URL | `'https://api.modora.xyz'` |
| `Config.APIToken` | Your API token (REQUIRED) | `''` |
| `Config.ReportCommand` | Command name | `'report'` |
| `Config.ReportKeybind` | Keybind (or `false` to disable) | `'F7'` |
| `Config.NearbyRadius` | Radius in meters for nearby players | `30.0` |
| `Config.MaxNearbyPlayers` | Maximum nearby players to show | `5` |
| `Config.Locale` | Language (`'nl'` or `'en'`) | `'nl'` |
| `Config.Debug` | Enable debug prints | `false` |

---

## 🔧 How It Works

The resource uses a direct API integration:

1. **API Communication**: Communicates with `api.modora.xyz` via HTTP/1.1
2. **Authentication**: Uses simple API token (Bearer token)
3. **Form Submission**: Reports are submitted directly to the API
4. **Ticket Creation**: Reports automatically become Discord tickets

---

## 🔐 Security

- **API Token Authentication**: Simple token-based authentication
- **HTTPS Only**: All communication uses encrypted HTTPS
- **IP Whitelisting**: Optional IP restrictions per server
- **Rate Limiting**: Built-in cooldown system

---

## 🐛 Troubleshooting

### Authentication failed

- Verify `Config.APIToken` matches the token in your dashboard
- Check that the token is correctly copied (no extra spaces)
- Enable `Config.Debug = true` for detailed logs

### Reports not submitting

- Check server console for errors
- Verify the API base URL is correct
- Check if player data is being sent correctly
- Enable debug mode to see detailed logs

### API connection errors

- Check firewall allows outbound connections on port 443 (HTTPS)
- Verify `api.modora.xyz` is accessible from your server
- Test connectivity: `curl https://api.modora.xyz/test`

---

## 📝 File Structure

```
modora-reports/
├── fxmanifest.lua    # Resource manifest
├── config.lua        # Configuration
├── client.lua         # Client-side logic
├── server.lua         # Server-side logic (API communication)
├── html/
│   ├── index.html    # Form modal HTML
│   ├── style.css     # Styling
│   └── script.js     # JavaScript
└── README.md         # This file
```

---

## 🔄 Version Management

The resource automatically checks for updates from GitHub releases on startup. When a new version is available, you'll see a notification in the server console.

---

## 🔧 Troubleshooting

### HTTP 0 Error

If you see `HTTP 0` errors in your FiveM server console, this means the server cannot connect to the API. Common causes and solutions:

#### 1. **Firewall Blocking HTTPS**
- **Problem**: Your server firewall is blocking outbound HTTPS connections (port 443)
- **Solution**: 
  - Allow outbound HTTPS (port 443) in your firewall
  - Test from server: `curl https://api.modora.xyz/test`
  - If curl fails, it's a firewall/network issue

#### 2. **Network Connectivity Issues**
- **Problem**: Server cannot reach the internet or DNS resolution fails
- **Solution**:
  - Test DNS: `nslookup api.modora.xyz` or `ping api.modora.xyz`
  - Check server network configuration
  - Verify server has internet access

#### 3. **SSL/TLS Certificate Issues (Most Common)**
- **Problem**: FiveM's HTTP client cannot verify the SSL certificate, even though `curl` works
- **This is a known FiveM issue** - FiveM uses a different SSL/TLS library than curl
- **Easiest Solution**: **Use HTTP instead of HTTPS** - No certificate updates needed!
  - Change `Config.ModoraAPIBase = 'https://api.modora.xyz'` to `'http://api.modora.xyz'`
  - HTTP works without any SSL/TLS certificate issues
  - Note: HTTP is less secure, but works reliably for FiveM integrations
- **Alternative Solutions** (if you want to use HTTPS):
  - Update to recommended FiveM artifact version (see below)
  - Update CA certificates: `sudo update-ca-certificates` (Linux)
  - Restart FiveM server after updating
  - Test with: `curl -v https://api.modora.xyz/test` (should work)

#### 4. **FiveM Artifact Version**
- **Problem**: Older FiveM artifact versions may have SSL/TLS compatibility issues
- **Solution**: Use the **recommended** artifact version (not "latest")
  - **Check current recommended version**:
    ```bash
    # Linux
    curl -s https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/recommended.json | jq -r '.version'
    
    # Windows
    curl -s https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/recommended.json | jq -r '.version'
    ```
  - **Update your server** to use the recommended artifact version
  - **Note**: Avoid using "latest" for production servers - use "recommended" for stability
  - Recent artifact versions (2024-2025) generally have better SSL/TLS support

#### 4. **Incorrect API Token**
- **Problem**: API token is missing, incorrect, or has whitespace
- **Solution**:
  - Verify token in `config.lua` matches the token from dashboard
  - Remove any leading/trailing spaces
  - Regenerate token in dashboard if needed
  - Enable `Config.Debug = true` to see token preview in logs

#### 5. **URL Configuration Error**
- **Problem**: API base URL is incorrectly formatted
- **Solution**:
  - Must start with `http://` or `https://`
  - Must NOT have trailing slash
  - Examples: 
    - `Config.ModoraAPIBase = 'http://api.modora.xyz'` (works without SSL/TLS issues)
    - `Config.ModoraAPIBase = 'https://api.modora.xyz'` (more secure, requires SSL/TLS)

#### Debug Steps

1. **Enable Debug Mode**:
   ```lua
   Config.Debug = true
   ```
   This will show detailed connection logs in your server console.

2. **Test API Connection**:
   The resource automatically tests the API connection on startup. Check your server console for:
   - `✅ API connection test successful!` - Connection works
   - `⚠️ API CONNECTION FAILED!` - Connection failed (see error details)

3. **Check Server Console**:
   Look for error messages that indicate the specific problem:
   - Connection timeout
   - DNS resolution failure
   - SSL certificate errors
   - Authentication failures

4. **Verify Configuration**:
   - API token is set and not empty
   - API base URL is correct
   - No syntax errors in `config.lua`

#### Still Having Issues?

**If `curl https://api.modora.xyz/test` works but FiveM still gets HTTP 0:**

This is a **FiveM HTTP client SSL/TLS compatibility issue**, not a network problem. 

**Quick Fix (Recommended):**
1. **Switch to HTTP** - No certificate updates needed!
   - Change `Config.ModoraAPIBase = 'https://api.modora.xyz'` to `'http://api.modora.xyz'`
   - Restart the resource
   - HTTP works without SSL/TLS certificate issues

**If you want to use HTTPS instead:**

1. **Check and update FiveM artifact version** (Most Important):
   ```bash
   # Check current recommended version
   curl -s https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/recommended.json | jq -r '.version'
   
   # Or for Windows:
   curl -s https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/recommended.json | jq -r '.version'
   ```
   - Update your server to use the **recommended** artifact (not "latest")
   - Recent artifact versions (2024-2025) have better SSL/TLS support
   - Check your current version in server startup logs or `run.sh`/`run.cmd`

2. **Update CA certificates**:
   ```bash
   sudo update-ca-certificates
   sudo apt-get update && sudo apt-get install -y ca-certificates  # Debian/Ubuntu
   ```

3. **Check FiveM server console** for SSL/TLS errors (look for certificate validation errors)

4. **Verify server time/date** is correct (SSL certificates are time-sensitive)

5. **Contact support** with:
   - Server console logs (with `Config.Debug = true`)
   - Output of `curl https://api.modora.xyz/test` (should work)
   - Your FiveM artifact version (check startup logs)
   - Operating system and version
   - Whether you're using txAdmin or manual installation

---

## 📞 Support

For issues or questions:
- Discord: https://discord.gg/modora
- Website: https://modora.xyz
- Documentation: https://modora.xyz/docs
- GitHub: https://github.com/ModoraLabs/modora-reports

---

## 📄 License

Copyright © 2025 Modora Labs. All rights reserved.
