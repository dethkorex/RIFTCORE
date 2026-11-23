# RIFTCORE Alpha 6.3.63

## Performance

- Reduced frame hitches during online play. Cloud backup checks skip rereading unchanged saves, and private messaging sets up its session key in the background.
- Reduced shadow rendering work across missions. Detailed platform surfaces stay visible, while simpler geometry casts their shadows.
- The animated HUD portrait now updates at 30 FPS independently of gameplay. The sector map draws its terrain lines in a single batch.
- Buster shots reuse trail, pulse and glow resources during sustained fire.
