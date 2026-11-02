CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS arsen_catalog_items_persian_name_trgm_idx
  ON arsen_catalog_items USING GIN ("persianName" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS arsen_catalog_items_generic_name_trgm_idx
  ON arsen_catalog_items USING GIN ("genericName" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS arsen_catalog_items_persian_brand_name_trgm_idx
  ON arsen_catalog_items USING GIN ("persianBrandName" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS arsen_catalog_items_brand_name_trgm_idx
  ON arsen_catalog_items USING GIN ("brandName" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS arsen_catalog_items_shape_name_trgm_idx
  ON arsen_catalog_items USING GIN ("shapeName" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS arsen_catalog_items_unit_trgm_idx
  ON arsen_catalog_items USING GIN ("unit" gin_trgm_ops);
