import { Slider } from "@/components/ui/slider"
import { Label } from "@/components/ui/label"
import { SliderControlProps } from "@/types/config"

const SliderControl = ({
  id,
  label,
  value,
  min,
  max,
  step,
  valueLabels,
  onChange
}: SliderControlProps) => (
  <div className="space-y-2">
    <div className="flex justify-between">
      <Label htmlFor={id}>{label}: {value}</Label>
    </div>
    <Slider 
      id={id} 
      value={[value]} 
      min={min} 
      max={max} 
      step={step} 
      className="w-full"
      onValueChange={(vals) => onChange(vals[0])}
    />
    <div className="flex justify-between text-xs text-muted-foreground">
      {valueLabels.map((label, index) => (
        <span key={index}>{label}</span>
      ))}
    </div>
  </div>
)

export default SliderControl;