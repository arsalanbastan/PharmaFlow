const { PrismaClient } = require('@prisma/client');

if (!process.env.DATABASE_URL || process.env.DATABASE_URL.trim() === '') {
  console.error('DATABASE_URL is not set in this PowerShell session.');
  console.error(
    'Set the Liara PUBLIC PostgreSQL DATABASE_URL privately in this terminal, then run this script again.',
  );
  process.exit(2);
}

const prisma = new PrismaClient();

let failed = false;

function summarizeRows(rows) {
  return {
    count: rows.length,
    updatedAt: rows.map((row) =>
      row.updatedAt instanceof Date
        ? row.updatedAt.toISOString()
        : String(row.updatedAt),
    ),
  };
}

async function check(label, action) {
  try {
    const result = await action();

    console.log(`\nPASS: ${label}`);

    if (Array.isArray(result)) {
      console.log(JSON.stringify(summarizeRows(result), null, 2));
    } else {
      console.log(result);
    }

    return result;
  } catch (error) {
    failed = true;

    console.error(`\nFAIL: ${label}`);
    console.error(`name: ${error?.name ?? '<none>'}`);
    console.error(`code: ${error?.code ?? '<none>'}`);
    console.error(`message: ${error?.message ?? String(error)}`);

    if (error?.meta !== undefined) {
      console.error(`meta: ${JSON.stringify(error.meta, null, 2)}`);
    }

    return null;
  }
}

async function main() {
  await check('company.count()', () => prisma.company.count());

  await check('findMany take=2, no orderBy', () =>
    prisma.company.findMany({
      take: 2,
    }),
  );

  await check('findMany orderBy updatedAt ASC', () =>
    prisma.company.findMany({
      orderBy: {
        updatedAt: 'asc',
      },
      take: 2,
    }),
  );

  await check('findMany orderBy id ASC', () =>
    prisma.company.findMany({
      orderBy: {
        id: 'asc',
      },
      take: 2,
    }),
  );

  const ordered = await check('findMany orderBy updatedAt ASC, id ASC', () =>
    prisma.company.findMany({
      orderBy: [{ updatedAt: 'asc' }, { id: 'asc' }],
      take: 3,
    }),
  );

  if (Array.isArray(ordered) && ordered.length > 0) {
    const last = ordered[ordered.length - 1];

    await check('cursor WHERE using updatedAt/id', () =>
      prisma.company.findMany({
        where: {
          OR: [
            {
              updatedAt: {
                gt: last.updatedAt,
              },
            },
            {
              updatedAt: last.updatedAt,
              id: {
                gt: last.id,
              },
            },
          ],
        },
        orderBy: [{ updatedAt: 'asc' }, { id: 'asc' }],
        take: 2,
      }),
    );
  }
}

main()
  .catch((error) => {
    failed = true;
    console.error('\nUNEXPECTED TOP-LEVEL FAILURE');
    console.error(error);
  })
  .finally(async () => {
    await prisma.$disconnect();

    if (failed) {
      process.exitCode = 1;
    }
  });
