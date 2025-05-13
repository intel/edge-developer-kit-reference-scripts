import { ConfigSectionProps } from "@/types/config"
import { ChevronUp, ChevronDown } from "lucide-react"
import { Card, CardHeader, CardTitle, CardContent } from "../ui/card"
import { useState } from "react"

export const ConfigSection = ({ title, icon, children }: ConfigSectionProps) => {
  const [expanded, setExpanded] = useState(true)
  
  const onToggle = () => {
    setExpanded((prev) => !prev)
  }
  
  return (
    <Card>
      <CardHeader 
        className="cursor-pointer hover:bg-muted/50 transition-colors rounded-t-lg"
        onClick={onToggle}
        aria-expanded={expanded}
      >
        <div className="flex items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            {icon}
            {title}
          </CardTitle>
          {expanded ? <ChevronUp className="h-5 w-5" /> : <ChevronDown className="h-5 w-5" />}
        </div>
      </CardHeader>
      {expanded && <CardContent className="space-y-4">{children}</CardContent>}
    </Card>
  )
}