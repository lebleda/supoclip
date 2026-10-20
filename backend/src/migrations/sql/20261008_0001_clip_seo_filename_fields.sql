-- SEO filename block for generated clips.
-- Exported clips are named: "<seo_title> - <seo_description> #tag1 #tag2_<suffix>.mp4"
ALTER TABLE generated_clips ADD COLUMN IF NOT EXISTS seo_title VARCHAR(120);
ALTER TABLE generated_clips ADD COLUMN IF NOT EXISTS seo_description VARCHAR(250);
ALTER TABLE generated_clips ADD COLUMN IF NOT EXISTS seo_tags TEXT;
