import { media } from "@kit.MediaKit";
import { fileIo } from "@kit.CoreFileKit";

export async function playThisForMe(r: string, tag = '') {
  let avPlayer: media.AVPlayer | undefined = undefined;
  try {
    avPlayer = await media.createAVPlayer();
  } catch (e) {
    console.error(`${tag} await media.createAVPlayer() error: ${e}.`);
  }

  if (avPlayer) {
    avPlayer.on('stateChange', (state: string, reason: media.StateChangeReason) => {
      console.warn(`${tag} avPlayer state change: ${state}.`);
      if (state == 'initialized') {
        avPlayer!.prepare().catch((e: BusinessError) => {
          console.warn(`${tag} avPlayer prepare error: ${e}.`);
        })
      }
      if (state == 'prepared') {
        avPlayer!.play().catch((e: BusinessError) => {
          console.warn(`${tag} avPlayer play error: ${e}.`);
        })
      }
      if (state == 'completed') {
        avPlayer!.release().catch((e: BusinessError) => {
          console.warn(`${tag} avPlayer release error: ${e}.`);
        })
      }
    });
    avPlayer!.on('error', (e: BusinessError) => {
      console.error(`${tag} avPlayer error: ${e}.`);
    });

    try {
      let file = fileIo.openSync(r, fileIo.OpenMode.READ_WRITE);
      avPlayer!.url = 'fd://' + file.fd;
    } catch (e) {
      console.error(`${tag} let file = fileIo.openSync(r, fileIo.OpenMode.READ_WRITE); error: ${e}.`);
    }
    console.log(`${tag} avPlayer.url = ${r}`);
  }
}