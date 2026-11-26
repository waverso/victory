//! The title's render scale set by us (`VICTORY_RENDER_SCALE=<fraction of
//! the output>`, e.g. 0.2667 for 1024x576 of 3840x2160; off by default).
//!
//! The title keeps its render scale at or above a lower limit it sets to
//! 2/3 (2560x1440 of 3840x2160), and FidelityFX scales the picture up to the
//! output. Patched in the prepared image: the limit is the scale asked for,
//! and the scale is the limit (a load in place of a max).

use anyhow::{Context, Result, ensure};
use victory_loader::PreparedImage;

/// The only build the patch knows.
const BUILD: &str = "b99f876b74d4a77f03af5f878223b27bd647b5c35a79d5decd9f716504239e93";
/// `mov dword [rcx+0x90], 2/3`, a call, `vmaxss xmm0, xmm0, [rsi+0x90]`,
/// `vmovss [rsi+0x94], xmm0`.
const AT: u32 = 0x028f_1e78;
const EXPECTED: [u8; 31] = [
    0xc7, 0x81, 0x90, 0, 0, 0, 0xab, 0xaa, 0x2a, 0x3f, 0xe8, 0x79, 0x24, 0x6c, 0xff, 0xc5, 0xfa, 0x5f, 0x86, 0x90, 0, 0,
    0, 0xc5, 0xfa, 0x11, 0x86, 0x94, 0, 0, 0,
];
/// Where the limit's immediate and the max's opcode lie in `EXPECTED`.
const LIMIT: std::ops::Range<usize> = 6..10;
const OPCODE: usize = 17;
/// `vmovss xmm0, [rsi+0x90]`.
const LOAD: u8 = 0x10;

/// The scale asked for, if any.
pub(super) fn asked() -> Option<f32> {
    let scale: f32 = std::env::var("VICTORY_RENDER_SCALE").ok()?.trim().parse().ok()?;
    (0.1..=1.0).contains(&scale).then_some(scale)
}

/// Patches `image` of build `build` to render at the scale asked for; the
/// scale if it did.
pub(super) fn apply(image: &mut PreparedImage, build: &str) -> Result<Option<f32>> {
    let Some(scale) = asked() else {
        return Ok(None);
    };
    ensure!(build == BUILD, "VICTORY_RENDER_SCALE does not know build {build}");
    let offset = image.info.rva_to_file_offset(AT).context("the render scale code is not in the image")? as usize;
    let bytes = image
        .bytes
        .get_mut(offset..offset + EXPECTED.len())
        .context("the render scale code lies outside the image")?;
    ensure!(bytes == EXPECTED, "the render scale code is not as expected");
    bytes[LIMIT].copy_from_slice(&scale.to_le_bytes());
    bytes[OPCODE] = LOAD;
    Ok(Some(scale))
}
