# GitHub Pages Setup Instructions

The web-based HWX parser in `hwx_dump_js/` is ready to deploy on GitHub Pages.

## Setup Steps

1. **Go to Repository Settings**
   - Navigate to: https://github.com/freedomtan/coreml_to_ane_hwx/settings/pages

2. **Configure GitHub Pages**
   - **Source**: Deploy from a branch
   - **Branch**: `main` 
   - **Folder**: `/ (root)`
   - Click **Save**

3. **Wait for Deployment**
   - GitHub will build and deploy automatically (takes 1-2 minutes)
   - Check the Actions tab for deployment status

4. **Access the Parser**
   - URL: `https://freedomtan.github.io/coreml_to_ane_hwx/hwx_dump_js/`
   - Direct link to `index.html` inside `hwx_dump_js/` directory

## What Gets Deployed

The parser is completely self-contained:
- `hwx_dump_js/index.html` - Web interface
- `hwx_dump_js/hwx_parser.js` - Parser implementation
- No build step required (pure HTML + JS)
- No server-side processing needed

## Technical Details

### Why It Works on GitHub Pages

✅ **Client-side only**: All parsing happens in the browser  
✅ **No dependencies**: Self-contained HTML + JavaScript  
✅ **Static files**: No build process or compilation needed  
✅ **No backend**: No server-side code to execute

### Architecture Support

The web parser supports all ANE generations:
- H13 (A14/M1) - Fixed offset format
- H14 (A15/M2) - Dense instruction stream
- H15 (A16/M3) - Dense instruction stream  
- H16 (A17 Pro/M4) - Dense + sparse instruction stream
- H17 (A18/M5) - Dense + sparse instruction stream
- H18 (A19) - Dense + sparse instruction stream

### Features

- Drag & drop `.hwx` files
- Interactive task list with navigation
- Register viewer for all hardware blocks (L2, PE, NE, TileDMA, KernelDMA)
- Dimension and format extraction
- Architecture detection
- Mach-O container parsing

## Verification

After deployment, test the parser:

1. Download a sample `.hwx` file:
   ```bash
   # Compile a test model
   ./coreml2hwx MobileNetV2.mlmodel debug
   # Result at: /tmp/hwx_output/MobileNetV2/model.hwx
   ```

2. Open the web parser: `https://freedomtan.github.io/coreml_to_ane_hwx/hwx_dump_js/`

3. Drag & drop the `.hwx` file

4. Verify:
   - Architecture detected correctly
   - Tasks list populated
   - Registers display properly
   - No console errors

## Troubleshooting

### 404 Not Found
- Wait 2-3 minutes for initial deployment
- Clear browser cache
- Check Actions tab for build status

### Parser Not Working
- Check browser console (F12) for errors
- Verify file is valid `.hwx` format
- Try different browser (Chrome, Firefox, Safari)

### Page Not Updating
- Hard refresh: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)
- GitHub Pages caches for ~10 minutes after push

## Custom Domain (Optional)

If you want a custom domain:
1. Add CNAME file: `echo "your-domain.com" > CNAME`
2. Configure DNS records at your domain provider
3. Update GitHub Pages settings with custom domain

---

**Status**: Ready to deploy - no code changes needed!
