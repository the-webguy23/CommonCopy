"""Convert the approved filled-path SVG to WPF vectors without changing geometry."""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
svg = ET.parse(sys.argv[1]).getroot()
wpf = 'http://schemas.microsoft.com/winfx/2006/xaml/presentation'
xaml = 'http://schemas.microsoft.com/winfx/2006/xaml'
ET.register_namespace('', wpf)
ET.register_namespace('x', xaml)
def tag(name): return '{'+wpf+'}'+name
root = ET.Element(tag('ResourceDictionary'))
image = ET.SubElement(root, tag('DrawingImage'), {'{'+xaml+'}Key':'ApprovedLogo'})
content = ET.SubElement(image, tag('DrawingImage.Drawing'))
group = ET.SubElement(content, tag('DrawingGroup'))
bounds = svg.attrib['viewBox'].split()
ET.SubElement(group, tag('GeometryDrawing'), {'Brush':'Transparent', 'Geometry':'M'+bounds[0]+','+bounds[1]+' h'+bounds[2]+' v'+bounds[3]+' h-'+bounds[2]+' Z'})
count = 0
for path in svg.iter('{http://www.w3.org/2000/svg}path'):
    transform = re.fullmatch(r'translate\(([-\d.]+)[, ]+([-\d.]+)\)', path.attrib['transform'])
    assert transform, 'Unsupported transform; do not approximate logo geometry'
    translated = ET.SubElement(group, tag('DrawingGroup'))
    prop = ET.SubElement(translated, tag('DrawingGroup.Transform'))
    ET.SubElement(prop, tag('TranslateTransform'), {'X':transform[1], 'Y':transform[2]})
    ET.SubElement(translated, tag('GeometryDrawing'), {'Brush':'{DynamicResource LogoInkBrush}' if path.attrib['fill']=='#000000' else '{DynamicResource LogoCopyBrush}', 'Geometry':'F1 '+path.attrib['d']})
    count += 1
assert count == 105
ET.indent(root)
Path(sys.argv[2]).write_text(ET.tostring(root, encoding='unicode')+'\n')
print(f'Preserved {count} filled paths and their exact translations.')
