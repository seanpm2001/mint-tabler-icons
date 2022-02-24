require "xml"

class String
  def indent(spaces : Int32 = 2) : String
    lines.join('\n') do |line|
      line.empty? ? line : (" " * spaces) + line
    end
  end
end

icons = {} of String => String

def copy(node, result)
  node.children.each do |child|
    next if child.text?
    next if child["stroke"]? == "none" && child["fill"]? == "none"

    result << %(<#{child.name})

    child.attributes.each do |attribute|
      result << %( #{attribute.name}="#{attribute.content}")
    end

    result << %(></#{child.name}>)

    copy(child, result)
  end
end

Dir.glob("tabler-icons/icons/*") do |file|
  document = XML.parse(File.read(file))

  if svg = document.first_element_child
    string = String.build do |result|
      result << %(<svg viewBox="#{svg["viewBox"]}">)
      result << "<g"
      result << %( stroke-linejoin="#{svg["stroke-linejoin"]}")
      result << %( stroke-linejoin="#{svg["stroke-linecap"]}")
      result << %( stroke-width="\#{strokeWidth}")
      result << %( stroke="currentColor")
      result << %( fill="#{svg["fill"]}">)

      copy(svg, result)

      result << "</g>"
      result << "</svg>"
    end

    name =
      File.basename(file, ".svg").upcase.gsub("-", "_")

    html =
      string.sub("<?xml version=\"1.0\"?>\n", "").indent

    icons[name] = html
  end
end

content =
  icons
    .map { |name, html| "const #{name} =(strokeWidth : Number) {#{html}}" }
    .join("\n\n")
    .indent

source =
  "module TablerIcons {\n#{content}\n}"

mainContent =
  icons
    .keys
    .map { |name| "<{ TablerIcons:#{name}(strokeWidth) }>" }
    .join("\n")
    .indent(8)

main =
  <<-MINT
  component Main {
    state strokeWidth : Number = 1

    style base {
      svg {
        height: 30px;
        width: 30px;
      }
    }

    fun render : Html {
      <div::base>
        <input
          onInput={(event : Html.Event) { next { strokeWidth = Number.fromString(Dom.getValue(event.target)) or 0 } }}
          value={Number.toString(strokeWidth)}
          step="0.25"
          type="range"
          min="1"
          max="5"/>

  #{mainContent}
      </div>
    }
  }
  MINT

File.write("source/Icons.mint", source)
File.write("source/Main.mint", main)
