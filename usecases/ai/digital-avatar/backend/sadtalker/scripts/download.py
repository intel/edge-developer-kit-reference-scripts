import gdown
import shutil
import zipfile
import os
import subprocess

if __name__ == "__main__":
    output = "face.zip"
    destination_dir = "checkpoints"

    if not os.path.exists(os.path.join(destination_dir, "epoch_00190_iteration_000400000_checkpoint.pt")):
        gdown.download(id="1-0xOf6g58OmtKtEWJlU3VlnfRqPN9Uq7", output=output, quiet=False)

        with zipfile.ZipFile(output, 'r') as zip_ref:
            zip_ref.extractall("extracted_files")

        if not os.path.exists(destination_dir):
            os.makedirs(destination_dir)
        for filename in os.listdir("extracted_files/face"):
            shutil.move(os.path.join("extracted_files/face", filename), destination_dir)

        # Clean up
        os.remove(output)
        shutil.rmtree("extracted_files")

    sadtalker_checkpoints = ["mapping_00109-model.pth.tar", "mapping_00229-model.pth.tar", "SadTalker_V0.0.2_256.safetensors", "SadTalker_V0.0.2_512.safetensors"]
    if not all(os.path.exists(os.path.join("checkpoints", checkpoint)) for checkpoint in sadtalker_checkpoints):
        subprocess.run(["bash", "scripts/download_sadtalker_models.sh"], check=True)

    if not os.path.exists(os.path.join("gfpgan", "weights")):
        subprocess.run(["bash", "scripts/download_gfpgan_models.sh"], check=True)