Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

module PageSummaryViewAddons
  def utf_summary
    # Parse the document
    full_content = @ruhoh.master_view(@model.pointer).render_content
    return nil unless full_content and !full_content.empty?
    content_doc = Nokogiri::HTML.fragment(full_content.force_encoding(Encoding::UTF_8), 'UTF-8')

    # Return a summary element if specified
    summary_el = content_doc.at_css('.summary')
    return summary_el.to_html(:encoding => 'UTF-8') unless summary_el.nil?

    # Get the configuration parameters
    # Default to the parameters provided in the page itself
    model_data = @model.data
    collection_config = @model.collection.config
    line_limit = model_data['summary_lines'] || collection_config['summary_lines']
    stop_at_header = model_data['summary_stop_at_header']
    stop_at_header = collection_config['summary_stop_at_header'] if stop_at_header.nil?

    # Create the summary element.
    summary_doc = Nokogiri::XML::Node.new("div", Nokogiri::HTML::Document.new)
    summary_doc["class"] = "summary"

    # All "heading" elements.
    headings = Nokogiri::HTML::ElementDescription::HEADING + ["header", "hgroup"]


    content_doc.children.each do |node|

      if stop_at_header == true
        # Detect first header after content
        if not (headings.include?(node.name) && node.content.empty?)
          stop_at_header = 1
        end
      elsif stop_at_header.is_a?(Integer) && headings.include?(node.name)
        if stop_at_header > 1
          stop_at_header -= 1;
        else
          summary_doc["class"] += " ellipsis"
          break
        end
      end

      if line_limit > 0 && summary_doc.content.lines.to_a.length > line_limit
        # Skip through leftover whitespace. Without this check, the summary
        # can be marked as ellipsis even if it isn't.
        unless node.text? && node.text.strip.empty?
          summary_doc["class"] += " ellipsis"
          break
        else
          next
        end
      end

      summary_doc << node
    end

    summary_doc.to_html :encoding => 'UTF-8'
  end

  def summary_present
    s = utf_summary
    !!s && !s.strip.empty?
  end
end
Ruhoh::Resources::Pages::ModelView.send(:include, PageSummaryViewAddons)
