-- Both languages share code; select translated page metadata at build time.
function Meta(meta)
  if pandoc.utils.stringify(meta.lang) == "ja" then
    for _, field in ipairs({"title", "subtitle"}) do
      if meta[field .. "-ja"] then
        meta[field] = meta[field .. "-ja"]
      end
    end
  end
  return meta
end
