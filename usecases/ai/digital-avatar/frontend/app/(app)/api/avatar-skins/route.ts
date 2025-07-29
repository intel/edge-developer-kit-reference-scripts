import { type NextRequest, NextResponse } from "next/server"
import fs from "fs"
import path from "path"

export async function GET() {
  try {
    // Dynamically retrieve mp4 files from the avatar-skins directory
    const skinsDir = path.join(process.cwd(), "public/assets/avatar-skins")
    const files = fs.readdirSync(skinsDir)
    const skins = files
      .filter((file: string) => file.endsWith(".mp4"))
      .map((file: string) => ({
        name: file.replace(/\.mp4$/, ""),
        url: `${file}`,
      }))
      
    return NextResponse.json(skins)
  } catch (error) {
    console.error("Error fetching avatar skins:", error)
    return NextResponse.json({ success: false, error: "Failed to fetch skins" }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const skinName = searchParams.get("skinName")
    if (!skinName) {
      return NextResponse.json({ success: false, error: "Missing skin name" }, { status: 400 })
    }
    const skinsDir = path.join(process.cwd(), "public/assets/avatar-skins")
    const filePath = path.join(skinsDir, `${skinName}.mp4`)
    const fileURL = new URL(`file://${filePath}`)
    if (!fs.existsSync(fileURL)) {
      return NextResponse.json({ success: false, error: "Skin not found" }, { status: 404 })
    }
    fs.unlinkSync(fileURL)
    return NextResponse.json({ success: true, message: "Skin deleted" })
  } catch (error) {
    console.error("Error deleting avatar skin:", error)
    return NextResponse.json({ success: false, error: "Failed to delete skin" }, { status: 500 })
  }
}
