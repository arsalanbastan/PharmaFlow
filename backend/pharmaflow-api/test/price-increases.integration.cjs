/* Run only against an isolated, disposable test database after migrations and build. */
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { PrismaClient } = require('@prisma/client');
const { PriceIncreasesService } = require('../dist/src/price-increases/price-increases.service');
const { AuditLogService } = require('../dist/src/audit/audit-log.service');
const { AuditContextService } = require('../dist/src/audit/audit-context.service');

const url = new URL(process.env.DATABASE_URL || '');
if (!['127.0.0.1', 'localhost'].includes(url.hostname) || !url.pathname.endsWith('_test')) throw new Error('Requires a localhost database ending in _test.');
const db = new PrismaClient();
const context = new AuditContextService();
const audit = new AuditLogService(db, context);
const service = new PriceIncreasesService(db, audit, {});
const manager = {userId:randomUUID(),displayName:'مدیر',role:'MANAGER'};
const staff1 = {userId:randomUUID(),displayName:'کارمند اول',role:'STAFF'};
const staff2 = {userId:randomUUID(),displayName:'کارمند دوم',role:'STAFF'};
const run = (actor, fn) => context.run({source:'MOBILE_APP',actorVerified:true,actorUserId:actor.userId,actorDisplayName:actor.displayName,actorRole:actor.role},fn);
(async()=>{
 try {
  const item=await run(manager,()=>service.create({productName:'آزمایش افزایش قیمت '+randomUUID(),category:'DRUG',newPrice:'1234567890123456.78',effectiveDate:'1405/08/18',source:'اطلاعیه شرکت'},manager));
  assert.equal(item.newPrice.toString(),'1234567890123456.78');
  const start=Date.now();
  const confirmations=await Promise.all(Array.from({length:8},()=>run(staff1,()=>service.confirm(item.id,staff1))));
  assert.equal(await db.priceIncreaseConfirmation.count({where:{priceIncreaseId:item.id}}),1);
  assert.equal(new Set(confirmations.map(c=>c.confirmedAt.toISOString())).size,1);
  assert.ok(confirmations[0].confirmedAt.getTime()>=start-1000);
  assert.equal(await db.auditLog.count({where:{entityId:item.id,action:'PRICE_INCREASE_CONFIRMED'}}),1);
  assert.ok(!(await service.list({status:'PENDING',q:item.productName},staff1)).items.some(i=>i.id===item.id));
  assert.ok((await service.list({status:'PENDING',q:item.productName},staff2)).items.some(i=>i.id===item.id));
  await run(staff2,()=>service.confirm(item.id,staff2));
  const history=await service.list({status:'CONFIRMED',q:item.productName},manager);
  assert.equal(history.items[0].confirmations.length,2);
  assert.equal(history.items[0].confirmations[1].displayName,staff2.displayName);
  const group = await run(manager, () => service.create({
    productName: 'همه شربت‌های اندانسترون ' + randomUUID(),
    productItems: ['برند اول', 'برند دوم'],
    category: 'DRUG',
    newPrice: '1000',
    effectiveDate: '1405/08/18',
    source: 'اطلاعیه',
  }, manager));
  await run(staff1, () => service.confirm(group.id, staff1, { itemIndex: 0, note: 'قیمت اصلاح شد' }));
  assert.equal((await service.list({ status: 'PENDING', q: group.productName }, staff1)).total, 1);
  assert.equal((await service.list({ status: 'CONFIRMED', q: group.productName }, manager)).total, 0);
  await run(staff1, () => service.confirm(group.id, staff1, { itemIndex: 1 }));
  const completed = await service.list({ status: 'CONFIRMED', q: group.productName }, staff1);
  assert.equal(completed.total, 1);
  assert.equal(completed.items[0].confirmations.find((row) => row.itemIndex === 0).note, 'قیمت اصلاح شد');
  assert.equal((await service.list({ status: 'PENDING', q: group.productName }, staff2)).total, 1);
  const requestKey = randomUUID().replaceAll('-', '') + '0'.repeat(16);
  const common = { category: 'GOODS', effectiveDate: '1405/08/18', source: 'تصویر آزمایشی' };
  const rows = [
    { ...common, productName: 'کالای اول', newPrice: '12000' },
    { ...common, productName: 'کالای دوم', newPrice: '35000' },
  ];
  const requests = await Promise.all(Array.from({ length: 3 }, () =>
    run(manager, () => service.createBatch(rows, manager, requestKey))));
  const ids = requests[0].items.map((row) => row.id);
  for (const result of requests) assert.deepEqual(result.items.map((row) => row.id).sort(), [...ids].sort());
  assert.equal(await db.auditLog.count({ where: { entityId: { in: ids }, action: 'PRICE_INCREASE_CREATED' } }), 2);
  const before=await db.priceIncrease.count();
  const failing=new PriceIncreasesService(db,{record:async()=>{throw new Error('audit failed')}},{});
  await assert.rejects(()=>failing.create({productName:'rollback test',category:'GOODS',newPrice:'10',effectiveDate:'1405/08/18',source:'test'},manager));
  assert.equal(await db.priceIncrease.count(),before);
  console.log('PASS: PostgreSQL migrations, decimal precision, 8 concurrent confirmations, per-user history, server timestamp, audit uniqueness, transaction rollback.');
 } finally {await db.$disconnect();}
})().catch(e=>{console.error(e);process.exitCode=1;});
