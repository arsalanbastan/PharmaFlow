# SQLite to PostgreSQL One-Time Importer

This importer migrates production data from a SQLite database into PostgreSQL using the existing Prisma models and PrismaService.

## Location

SQLite source file default path:

- `D:/Projects/PharmaFlow/tools/migration/pharmaflow.db`

You can override this path using `--sqlite=<path>` or `SQLITE_PATH`.

## Safety behavior

- Uses PrismaService for PostgreSQL writes (no raw PostgreSQL SQL).
- Stops on critical validation/import errors.
- Does not delete existing PostgreSQL data.
- Aborts by default if target PostgreSQL tables are not empty.
- To intentionally append data, pass `--allow-non-empty`.

## Run

```bash
npm run import:sqlite
```

Optional custom path:

```bash
npm run import:sqlite -- --sqlite="D:/Projects/PharmaFlow/tools/migration/pharmaflow.db"
```

Optional allow non-empty target tables:

```bash
npm run import:sqlite -- --allow-non-empty
```
