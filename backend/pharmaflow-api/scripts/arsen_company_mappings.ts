import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type MappingSeed = {
  arsenBusinessPartnerId: number;
  arsenName: string;
  companyId: string;
  companyName: string;
};

const EXPECTED_MAPPING_COUNT = 95;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const mappings: MappingSeed[] = [
  {
    "arsenBusinessPartnerId": 535,
    "arsenName": "پخش ارغوان کالای جنوب لیان",
    "companyId": "6eaa89ab-f4b4-48a4-a60f-09ec2a4196a4",
    "companyName": "ارغوان کالای جنوب"
  },
  {
    "arsenBusinessPartnerId": 1553,
    "arsenName": "لارین پخش ایرانیان کهن",
    "companyId": "421fb8dd-da91-4f00-8cc8-547c18b57cd0",
    "companyName": "لارین پخش"
  },
  {
    "arsenBusinessPartnerId": 1586,
    "arsenName": "سلامت گستر  شایان اعتماد",
    "companyId": "2a11965b-ba35-4da6-b02a-7fb5236eb5d1",
    "companyName": "سلامت گستر شایان"
  },
  {
    "arsenBusinessPartnerId": 527,
    "arsenName": "قاسم ایران",
    "companyId": "46babf29-3699-461a-afa4-d92e96547460",
    "companyName": "مینو(قاسم ایران)"
  },
  {
    "arsenBusinessPartnerId": 531,
    "arsenName": "همادیس سلامت محور",
    "companyId": "7e59f854-ee85-454e-9d52-42c30081b7b4",
    "companyName": "همادیس"
  },
  {
    "arsenBusinessPartnerId": 1573,
    "arsenName": "توسعه وشه خاورمیانه(کیان ایده)",
    "companyId": "400cb890-c529-4cf4-a996-3f99b6eb9156",
    "companyName": "وشه"
  },
  {
    "arsenBusinessPartnerId": 1575,
    "arsenName": "گوهر گستر",
    "companyId": "348ff799-c01d-49be-8596-12ab430c5aef",
    "companyName": "گوهر گستر تابناک"
  },
  {
    "arsenBusinessPartnerId": 547,
    "arsenName": "پخش تجهیزات پزشکی بابک",
    "companyId": "8db27ef6-7171-4f14-b31e-4c7a33bab2eb",
    "companyName": "پخش بابک"
  },
  {
    "arsenBusinessPartnerId": 1548,
    "arsenName": "شهاب آکام پخش جنوب",
    "companyId": "b0472f51-471c-475d-b27a-b7da4f622ecb",
    "companyName": "شهاب آکام"
  },
  {
    "arsenBusinessPartnerId": 1596,
    "arsenName": "فرین سلامت",
    "companyId": "0a547b93-fd03-4c41-b975-09ef597a4418",
    "companyName": "فرین سلامت مهر آسا"
  },
  {
    "arsenBusinessPartnerId": 1601,
    "arsenName": "هیوا",
    "companyId": "f4ffc3c5-895b-4cca-98cf-1db10efbd6bc",
    "companyName": "پخش هیوا(علی اکبر سهرابی)"
  },
  {
    "arsenBusinessPartnerId": 1559,
    "arsenName": "متفرقه",
    "companyId": "60c646f1-9f73-4d99-9a92-730b4f0c4291",
    "companyName": "سایر"
  },
  {
    "arsenBusinessPartnerId": 1603,
    "arsenName": "اندیش مایسا",
    "companyId": "dfbe12a1-8b00-436e-83d1-de97444b867f",
    "companyName": "مایسا"
  },
  {
    "arsenBusinessPartnerId": 517,
    "arsenName": "داروگستر رازی",
    "companyId": "7a1d4362-55e5-4047-8ebd-779c56ed24fc",
    "companyName": "رازی"
  },
  {
    "arsenBusinessPartnerId": 1574,
    "arsenName": "یکتا همای سلامت محور",
    "companyId": "852eb210-bda2-4e09-8212-606c4c4ae0b4",
    "companyName": "یکتا همای سلامت محور"
  },
  {
    "arsenBusinessPartnerId": 1571,
    "arsenName": "نسیم گستر بوشهر",
    "companyId": "8b449e8e-83ed-4527-93bf-04011268c82b",
    "companyName": "نسیم گستر بوشهر"
  },
  {
    "arsenBusinessPartnerId": 1558,
    "arsenName": "بازرگانی گل نرگس",
    "companyId": "f2bc1dcc-5338-4c3b-a975-c17a64df7662",
    "companyName": "بازرگانی گل نرگس"
  },
  {
    "arsenBusinessPartnerId": 1563,
    "arsenName": "پخش سیلویا (صفری شیراز)",
    "companyId": "8fcb9473-5c03-40b0-ad33-1fad9314048c",
    "companyName": "پخش سیلویا (صفری شیراز)"
  },
  {
    "arsenBusinessPartnerId": 1568,
    "arsenName": "زاگرس زرین پارس (مای بیبی)",
    "companyId": "dbc2a07c-fa2e-469e-8235-6177b1871d56",
    "companyName": "زاگرس زرین پارس (مای بیبی)"
  },
  {
    "arsenBusinessPartnerId": 1604,
    "arsenName": "تانا پخش",
    "companyId": "12ef42f1-98d2-41a2-93ab-e98eff743af7",
    "companyName": "تانا پخش"
  },
  {
    "arsenBusinessPartnerId": 1592,
    "arsenName": "تجارت رامان",
    "companyId": "f63efdff-5865-4efc-8369-e68b76fc87ee",
    "companyName": "تجارت رامان"
  },
  {
    "arsenBusinessPartnerId": 1590,
    "arsenName": "آرکا طب",
    "companyId": "a44d161c-a0d2-48a0-ab2c-0dd539c73505",
    "companyName": "آرکا طب"
  },
  {
    "arsenBusinessPartnerId": 1569,
    "arsenName": "هستی گستر غزال",
    "companyId": "c710e29c-782c-4940-a7c3-5a173ddf7ba4",
    "companyName": "هستی گستر غزال"
  },
  {
    "arsenBusinessPartnerId": 1570,
    "arsenName": "لوازم پزشکی کیاطب",
    "companyId": "bc83ad38-bdb4-4215-9aa0-8045df84c3c3",
    "companyName": "لوازم پزشکی کیاطب"
  },
  {
    "arsenBusinessPartnerId": 1595,
    "arsenName": "آرسان",
    "companyId": "a54611c2-2bdf-483b-afb4-f60352b8d1cf",
    "companyName": "آرسان"
  },
  {
    "arsenBusinessPartnerId": 1602,
    "arsenName": "اوتانا",
    "companyId": "433b465c-285e-4aae-89de-11ac30838d59",
    "companyName": "اوتانا"
  },
  {
    "arsenBusinessPartnerId": 1566,
    "arsenName": "تابش نور",
    "companyId": "ef19a0e3-d686-4e61-87d3-72a907b2492b",
    "companyName": "تابش نور"
  },
  {
    "arsenBusinessPartnerId": 503,
    "arsenName": "تجهیز گران طب نوین",
    "companyId": "b5b6947d-4bc1-4c19-a68b-c2da8ec7c53c",
    "companyName": "تجهیز گران طب نوین"
  },
  {
    "arsenBusinessPartnerId": 1597,
    "arsenName": "تجهیزات پزشکی محمدپور",
    "companyId": "9f57656a-94f0-4c8a-9441-f59198659dcf",
    "companyName": "تجهیزات پزشکی محمدپور"
  },
  {
    "arsenBusinessPartnerId": 1552,
    "arsenName": "داروکده",
    "companyId": "406c04a0-469f-4c1d-818c-db64fed7aa63",
    "companyName": "داروکده"
  },
  {
    "arsenBusinessPartnerId": 1584,
    "arsenName": "سبز دارو سپاهان",
    "companyId": "2fe1f146-6bfa-4471-b785-4a1550d533e9",
    "companyName": "سبز دارو سپاهان"
  },
  {
    "arsenBusinessPartnerId": 1599,
    "arsenName": "سرمه",
    "companyId": "f9725fc3-e305-441a-a1e0-3cf813993635",
    "companyName": "سرمه"
  },
  {
    "arsenBusinessPartnerId": 429,
    "arsenName": "سینا پخش صبا",
    "companyId": "e8d649af-db78-4867-9b49-6665935b20e1",
    "companyName": "سینا پخش ژن"
  },
  {
    "arsenBusinessPartnerId": 525,
    "arsenName": "داروپخش",
    "companyId": "cf9cf073-ec0f-4231-91d7-387f4ba7d563",
    "companyName": "داروپخش"
  },
  {
    "arsenBusinessPartnerId": 9,
    "arsenName": "البرز",
    "companyId": "c1abb288-f2f3-414b-b228-9b8a8f8b9b8b",
    "companyName": "البرز"
  },
  {
    "arsenBusinessPartnerId": 374,
    "arsenName": "شفا آراد",
    "companyId": "502ef8c4-a2f5-4b7f-b69a-26abbf919ee5",
    "companyName": "شفا آراد"
  },
  {
    "arsenBusinessPartnerId": 529,
    "arsenName": "فردوس",
    "companyId": "e28433fb-1f3f-40e6-b0ee-6ef999d44f94",
    "companyName": "فردوس"
  },
  {
    "arsenBusinessPartnerId": 11,
    "arsenName": "بهستان پخش",
    "companyId": "5eb62511-0253-4551-be2b-2f79f2e0e20e",
    "companyName": "بهستان"
  },
  {
    "arsenBusinessPartnerId": 52,
    "arsenName": "آدورا طب",
    "companyId": "0d14eaac-5140-451a-87c4-27c4a057301e",
    "companyName": "آدورا طب"
  },
  {
    "arsenBusinessPartnerId": 530,
    "arsenName": "پخش دوست من",
    "companyId": "458c10da-5963-44bb-8792-2331467f4a26",
    "companyName": "پخش دوست من"
  },
  {
    "arsenBusinessPartnerId": 10,
    "arsenName": "الیت دارو",
    "companyId": "0e05214b-d1ec-41c7-b9a8-3d9c1ac534b7",
    "companyName": "الیت دارو"
  },
  {
    "arsenBusinessPartnerId": 1561,
    "arsenName": "داروگستر طوبی",
    "companyId": "f3cef864-1a98-45e6-aa39-ca2af67a944d",
    "companyName": "داروگستر طوبی"
  },
  {
    "arsenBusinessPartnerId": 526,
    "arsenName": "هجرت",
    "companyId": "f321289b-fca7-4e08-be4b-82eaee77aa49",
    "companyName": "هجرت"
  },
  {
    "arsenBusinessPartnerId": 12,
    "arsenName": "باريج اسانس",
    "companyId": "e7d0d01e-53a7-40da-8383-19304febddad",
    "companyName": "باریج اسانس"
  },
  {
    "arsenBusinessPartnerId": 528,
    "arsenName": "رازی",
    "companyId": "7a1d4362-55e5-4047-8ebd-779c56ed24fc",
    "companyName": "رازی"
  },
  {
    "arsenBusinessPartnerId": 56,
    "arsenName": "داروسازان التیام",
    "companyId": "52ac6134-5a86-4a02-aab7-84ec81a38b63",
    "companyName": "داروسازان التیام"
  },
  {
    "arsenBusinessPartnerId": 369,
    "arsenName": "دی دارو امید",
    "companyId": "e69920c2-f286-454b-ab26-6397ab35a448",
    "companyName": "دی دارو امید"
  },
  {
    "arsenBusinessPartnerId": 1576,
    "arsenName": "درمان یاب",
    "companyId": "e822692a-a246-4ba4-88e8-ded11ca5c905",
    "companyName": "درمان یاب"
  },
  {
    "arsenBusinessPartnerId": 23,
    "arsenName": "محیا دارو",
    "companyId": "fa52e01f-0046-49e5-baf4-59b416997870",
    "companyName": "محیا دارو"
  },
  {
    "arsenBusinessPartnerId": 51,
    "arsenName": "داروگستر نخبگان",
    "companyId": "21334e01-1b87-48a6-8ab1-5a125179fc60",
    "companyName": "داروگستر نخبگان"
  },
  {
    "arsenBusinessPartnerId": 383,
    "arsenName": "شرکت پخش کارن",
    "companyId": "c2c1301d-dcfa-478f-9087-5dcbb157f3aa",
    "companyName": "کارن"
  },
  {
    "arsenBusinessPartnerId": 533,
    "arsenName": "رایان پخش زمرد",
    "companyId": "cebfb279-eb47-4789-8a8a-e3f035975edd",
    "companyName": "رایان پخش زمرد"
  },
  {
    "arsenBusinessPartnerId": 41,
    "arsenName": "پورا پخش",
    "companyId": "efd39fd6-988d-4b73-b5a3-341fc6359e95",
    "companyName": "پوراپخش"
  },
  {
    "arsenBusinessPartnerId": 532,
    "arsenName": "دانا طراوت پارس",
    "companyId": "3d900698-3935-48c7-86da-e47bf68207ca",
    "companyName": "دانا طراوت پارس"
  },
  {
    "arsenBusinessPartnerId": 1556,
    "arsenName": "پخش بهداشت گستر جنوب",
    "companyId": "c1bbd012-d026-4daa-926f-ee02e9840f89",
    "companyName": "بهداشت گستر جنوب"
  },
  {
    "arsenBusinessPartnerId": 1554,
    "arsenName": "پارس مدیکال",
    "companyId": "d7e17720-142a-4764-bb6c-4bca51cc0723",
    "companyName": "پارس مدیکال(سورا سلامت)"
  },
  {
    "arsenBusinessPartnerId": 1549,
    "arsenName": "لابراتوار اخوی",
    "companyId": "c6d04b0d-e93a-4c50-b771-9a22522154ed",
    "companyName": "لابراتوار اخوی"
  },
  {
    "arsenBusinessPartnerId": 545,
    "arsenName": "آریان کیمیا تک",
    "companyId": "87d976e6-7324-45ca-bb83-856b9f28e294",
    "companyName": "آریان کیمیا تک"
  },
  {
    "arsenBusinessPartnerId": 115,
    "arsenName": "سینا پخش ژن",
    "companyId": "e8d649af-db78-4867-9b49-6665935b20e1",
    "companyName": "سینا پخش ژن"
  },
  {
    "arsenBusinessPartnerId": 534,
    "arsenName": "پخش آسیا نوید گستر آذرخش",
    "companyId": "b26c60af-e7a1-4359-8c18-ab1e769f6da5",
    "companyName": "پخش آسیا"
  },
  {
    "arsenBusinessPartnerId": 1585,
    "arsenName": "سپهر بهداشت ایرانیان",
    "companyId": "c5a6cd96-f0fe-4ed0-af97-490792230ded",
    "companyName": "سپهر بهداشت ایرانیان"
  },
  {
    "arsenBusinessPartnerId": 522,
    "arsenName": "مهبان دارو",
    "companyId": "98c8d9b5-3aa0-4cf6-bcfc-009887dfbf9a",
    "companyName": "مهبان دارو"
  },
  {
    "arsenBusinessPartnerId": 427,
    "arsenName": "سایه سمن",
    "companyId": "f6972265-4f4c-4023-a23e-69a21f335a6e",
    "companyName": "سایه سمن"
  },
  {
    "arsenBusinessPartnerId": 542,
    "arsenName": "برزویه حکیم",
    "companyId": "2e62322d-8dae-4433-b894-c5051450dded",
    "companyName": "برزویه حکیم"
  },
  {
    "arsenBusinessPartnerId": 1557,
    "arsenName": "شکوفا منش",
    "companyId": "e2587e47-1e3c-4cba-9b34-b743823d3efa",
    "companyName": "شکوفامنش"
  },
  {
    "arsenBusinessPartnerId": 536,
    "arsenName": "پخش آستان",
    "companyId": "560fbb8d-9b2c-4967-861a-890f4084612b",
    "companyName": "پخش آستان"
  },
  {
    "arsenBusinessPartnerId": 1555,
    "arsenName": "کیمیا گستر اسطوره فرزان پارس",
    "companyId": "f05cc92b-bb19-47e8-8636-bb0a595b550c",
    "companyName": "کیمیا گستر پارس"
  },
  {
    "arsenBusinessPartnerId": 1562,
    "arsenName": "داروگستر پیشرو پارسیان",
    "companyId": "3edf890a-1657-4f33-a2da-a09532bc4587",
    "companyName": "داروگستر پیشرو پارسیان"
  },
  {
    "arsenBusinessPartnerId": 538,
    "arsenName": "پونل برسام",
    "companyId": "ee01d2a5-eb51-43b7-9c48-e18720a74427",
    "companyName": "پوبر (پونل برسام)"
  },
  {
    "arsenBusinessPartnerId": 314,
    "arsenName": "پخش دارویی اکسیر",
    "companyId": "087dd77a-7fdb-4796-9ac4-61a73c395b27",
    "companyName": "پخش اکسیر"
  },
  {
    "arsenBusinessPartnerId": 370,
    "arsenName": "سلامت پخش هستی",
    "companyId": "ee91469a-e3f3-4eb7-a242-4a2a4159714e",
    "companyName": "سلامت پخش هستی"
  },
  {
    "arsenBusinessPartnerId": 460,
    "arsenName": "ممتاز",
    "companyId": "63a9e511-7ada-4125-8c1c-fc84bbf1af3a",
    "companyName": "ممتاز"
  },
  {
    "arsenBusinessPartnerId": 1582,
    "arsenName": "میلان پارس فارمد",
    "companyId": "42571372-63bd-44b3-a7dd-30e23da69fd9",
    "companyName": "میلان پارس فارمد"
  },
  {
    "arsenBusinessPartnerId": 1580,
    "arsenName": "آراد پخش وسیع",
    "companyId": "3fd7954c-5c00-4e3c-90f7-91beab63b732",
    "companyName": "آراد پخش وسیع(مای بیبی)"
  },
  {
    "arsenBusinessPartnerId": 1589,
    "arsenName": "نفس",
    "companyId": "d82995b0-1468-48b2-87a5-73ca12fc081e",
    "companyName": "پخش نفس"
  },
  {
    "arsenBusinessPartnerId": 466,
    "arsenName": "بهرسان دارو",
    "companyId": "5bd06caa-f1ee-414e-a4e2-4336ce333ddf",
    "companyName": "بهرسان دارو"
  },
  {
    "arsenBusinessPartnerId": 543,
    "arsenName": "درنیکا سپند مینا",
    "companyId": "9a636e69-ce20-4741-ab71-41a6854d0107",
    "companyName": "دسپینا (درنیکا سپند)"
  },
  {
    "arsenBusinessPartnerId": 1583,
    "arsenName": "نگاه برتر",
    "companyId": "b6a8950a-197e-4a58-b524-d68b9a5792a3",
    "companyName": "نگاه برتر"
  },
  {
    "arsenBusinessPartnerId": 1593,
    "arsenName": "آوای گلپر",
    "companyId": "495ed607-e4c8-43ed-9741-dedb705b36e3",
    "companyName": "آوای گلپر"
  },
  {
    "arsenBusinessPartnerId": 1550,
    "arsenName": "نویان بهداشت ایرانیان",
    "companyId": "ffe60d49-8fb4-4ca1-ad66-d26da4763b6b",
    "companyName": "نویان بهداشت"
  },
  {
    "arsenBusinessPartnerId": 1565,
    "arsenName": "بهداشت سلامت شیراز",
    "companyId": "d923c99d-4251-4ad5-ac78-ac9e3600421f",
    "companyName": "بهداشت سلامت شیراز"
  },
  {
    "arsenBusinessPartnerId": 1587,
    "arsenName": "حسام گستر پری چهره",
    "companyId": "fc398fba-038e-4e54-9421-34e73fefbc94",
    "companyName": "حسام گستر پری چهره"
  },
  {
    "arsenBusinessPartnerId": 1581,
    "arsenName": "سام سیروان گستر آرسام",
    "companyId": "872f897c-cb64-4040-b5a4-a5f6d62e79f7",
    "companyName": "سام سیروان گستر آرسام"
  },
  {
    "arsenBusinessPartnerId": 548,
    "arsenName": "اهورا پخش امین",
    "companyId": "7de07b27-e55b-490a-90df-15d9cdf0d1f2",
    "companyName": "اهورا پخش امین"
  },
  {
    "arsenBusinessPartnerId": 1567,
    "arsenName": "تجهیزات پزشکی دراک",
    "companyId": "f61cdc7e-b89a-480b-b427-ad5f045bbcab",
    "companyName": "تجهیزات پزشکی دراک"
  },
  {
    "arsenBusinessPartnerId": 1572,
    "arsenName": "راد تجارت ایرانیان کهن",
    "companyId": "9dca6b3b-8748-456a-9087-5ea08c7352ea",
    "companyName": "راد تجارت ایرانیان کهن"
  },
  {
    "arsenBusinessPartnerId": 1600,
    "arsenName": "اکسین تجارت",
    "companyId": "0a18d8d8-0bee-45a4-889e-827f0f80358b",
    "companyName": "اکسین تجارت"
  },
  {
    "arsenBusinessPartnerId": 493,
    "arsenName": "مشا طب",
    "companyId": "5757dea4-3c00-4892-83a3-3be3adda7eaa",
    "companyName": "مشا طب"
  },
  {
    "arsenBusinessPartnerId": 1564,
    "arsenName": "شمس کالای لیان",
    "companyId": "b41597e5-0cef-498f-9b1f-c01cc7841395",
    "companyName": "شمس کالای لیان"
  },
  {
    "arsenBusinessPartnerId": 544,
    "arsenName": "دسپینا",
    "companyId": "9a636e69-ce20-4741-ab71-41a6854d0107",
    "companyName": "دسپینا (درنیکا سپند)"
  },
  {
    "arsenBusinessPartnerId": 1577,
    "arsenName": "پرگاس طب",
    "companyId": "d68a5534-0b43-40d0-82c7-1dfe97971cc2",
    "companyName": "پرگاس طب"
  },
  {
    "arsenBusinessPartnerId": 1591,
    "arsenName": "پخش نوین اندیشه",
    "companyId": "6a2f5284-3032-4ced-9287-ab414d3b7583",
    "companyName": "پخش نوین اندیشه"
  },
  {
    "arsenBusinessPartnerId": 546,
    "arsenName": "پخش بهداشتی بزرگمهر",
    "companyId": "a6a403db-2a2d-4326-a87a-e8d8b59c4f2c",
    "companyName": "پخش بزرگمهر"
  },
  {
    "arsenBusinessPartnerId": 1578,
    "arsenName": "رایا نیک پخش لیان",
    "companyId": "d82db7ba-4a6e-4e22-a14c-9a5dcf2a15e9",
    "companyName": "رایا نیک پخش لیان"
  },
  {
    "arsenBusinessPartnerId": 432,
    "arsenName": "سها هلال",
    "companyId": "8be19d4b-ae90-4bc4-9427-35c006e12d52",
    "companyName": "پخش سها هلال"
  }
];

function validateStaticMapping(): void {
  if (mappings.length !== EXPECTED_MAPPING_COUNT) {
    throw new Error(`Expected ${EXPECTED_MAPPING_COUNT} mappings, got ${mappings.length}.`);
  }

  const partnerIds = new Set<number>();

  for (const item of mappings) {
    if (!Number.isInteger(item.arsenBusinessPartnerId) || item.arsenBusinessPartnerId <= 0) {
      throw new Error(`Invalid Arsen BusinessPartnerID: ${item.arsenBusinessPartnerId}.`);
    }

    if (partnerIds.has(item.arsenBusinessPartnerId)) {
      throw new Error(`Duplicate Arsen BusinessPartnerID: ${item.arsenBusinessPartnerId}.`);
    }

    partnerIds.add(item.arsenBusinessPartnerId);

    if (!item.arsenName.trim()) {
      throw new Error(`Missing Arsen name for BusinessPartnerID ${item.arsenBusinessPartnerId}.`);
    }

    if (!UUID_PATTERN.test(item.companyId)) {
      throw new Error(`Invalid PharmaFlow company UUID for BusinessPartnerID ${item.arsenBusinessPartnerId}.`);
    }
  }
}

async function inspectCurrentState() {
  const companyIds = [...new Set(mappings.map((item) => item.companyId))];
  const arsenIds = mappings.map((item) => item.arsenBusinessPartnerId);

  const [companies, existingMappings] = await Promise.all([
    prisma.company.findMany({
      where: { id: { in: companyIds } },
      select: { id: true, name: true, archivedAt: true, deletedAt: true },
    }),
    prisma.arsenCompanyMapping.findMany({
      where: { arsenBusinessPartnerId: { in: arsenIds } },
    }),
  ]);

  const companiesById = new Map(companies.map((item) => [item.id, item]));
  const existingByArsenId = new Map(
    existingMappings.map((item) => [item.arsenBusinessPartnerId, item]),
  );

  const missingCompanies = companyIds.filter((id) => !companiesById.has(id));
  const deletedCompanies = companies.filter((item) => item.deletedAt != null);
  const archivedCompanies = companies.filter((item) => item.archivedAt != null);

  const conflicts = mappings.filter((item) => {
    const existing = existingByArsenId.get(item.arsenBusinessPartnerId);
    return existing != null && existing.companyId !== item.companyId;
  });

  const toCreate = mappings.filter(
    (item) => !existingByArsenId.has(item.arsenBusinessPartnerId),
  );

  const toRename = mappings.filter((item) => {
    const existing = existingByArsenId.get(item.arsenBusinessPartnerId);
    return existing != null && existing.arsenName !== item.arsenName;
  });

  return {
    companyIds,
    companiesById,
    existingByArsenId,
    missingCompanies,
    deletedCompanies,
    archivedCompanies,
    conflicts,
    toCreate,
    toRename,
  };
}

function printSummary(
  mode: 'CHECK' | 'APPLY',
  state: Awaited<ReturnType<typeof inspectCurrentState>>,
): void {
  console.log(`MODE=${mode}`);
  console.log(`EXPECTED_MAPPING_COUNT=${EXPECTED_MAPPING_COUNT}`);
  console.log(`STATIC_MAPPING_COUNT=${mappings.length}`);
  console.log(`UNIQUE_ARSEN_IDS=${new Set(mappings.map((item) => item.arsenBusinessPartnerId)).size}`);
  console.log(`UNIQUE_COMPANY_IDS=${state.companyIds.length}`);
  console.log(`EXISTING_MAPPING_COUNT=${state.existingByArsenId.size}`);
  console.log(`TO_CREATE=${state.toCreate.length}`);
  console.log(`TO_RENAME=${state.toRename.length}`);
  console.log(`MISSING_COMPANIES=${state.missingCompanies.length}`);
  console.log(`DELETED_COMPANIES=${state.deletedCompanies.length}`);
  console.log(`ARCHIVED_COMPANIES=${state.archivedCompanies.length}`);
  console.log(`CONFLICTS=${state.conflicts.length}`);
}

async function applyMappings(
  state: Awaited<ReturnType<typeof inspectCurrentState>>,
): Promise<void> {
  if (state.missingCompanies.length > 0) {
    throw new Error(`Missing PharmaFlow companies: ${state.missingCompanies.join(', ')}`);
  }

  if (state.deletedCompanies.length > 0) {
    throw new Error(
      `Mapped PharmaFlow companies are soft-deleted: ${state.deletedCompanies.map((item) => item.id).join(', ')}`,
    );
  }

  if (state.conflicts.length > 0) {
    throw new Error(
      `Existing Arsen mappings point to different companies: ${state.conflicts.map((item) => item.arsenBusinessPartnerId).join(', ')}`,
    );
  }

  await prisma.$transaction(async (tx) => {
    for (const item of mappings) {
      const existing = await tx.arsenCompanyMapping.findUnique({
        where: { arsenBusinessPartnerId: item.arsenBusinessPartnerId },
      });

      if (existing == null) {
        const created = await tx.arsenCompanyMapping.create({
          data: {
            arsenBusinessPartnerId: item.arsenBusinessPartnerId,
            arsenName: item.arsenName,
            companyId: item.companyId,
          },
        });

        await tx.auditLog.create({
          data: {
            source: 'SYSTEM',
            actorDisplayName: 'ARSEN_MAPPING_IMPORT',
            actorVerified: false,
            action: 'CREATE',
            entityType: 'ARSEN_COMPANY_MAPPING',
            entityId: created.id,
            afterData: {
              arsenBusinessPartnerId: created.arsenBusinessPartnerId,
              arsenName: created.arsenName,
              companyId: created.companyId,
            } satisfies Prisma.InputJsonValue,
          },
        });

        continue;
      }

      if (existing.companyId !== item.companyId) {
        throw new Error(
          `Refusing to remap Arsen BusinessPartnerID ${item.arsenBusinessPartnerId} from ${existing.companyId} to ${item.companyId}.`,
        );
      }

      if (existing.arsenName !== item.arsenName) {
        const updated = await tx.arsenCompanyMapping.update({
          where: { id: existing.id },
          data: { arsenName: item.arsenName },
        });

        await tx.auditLog.create({
          data: {
            source: 'SYSTEM',
            actorDisplayName: 'ARSEN_MAPPING_IMPORT',
            actorVerified: false,
            action: 'UPDATE_SOURCE_NAME',
            entityType: 'ARSEN_COMPANY_MAPPING',
            entityId: updated.id,
            beforeData: {
              arsenBusinessPartnerId: existing.arsenBusinessPartnerId,
              arsenName: existing.arsenName,
              companyId: existing.companyId,
            } satisfies Prisma.InputJsonValue,
            afterData: {
              arsenBusinessPartnerId: updated.arsenBusinessPartnerId,
              arsenName: updated.arsenName,
              companyId: updated.companyId,
            } satisfies Prisma.InputJsonValue,
          },
        });
      }
    }
  });
}

async function main(): Promise<void> {
  validateStaticMapping();

  const apply = process.argv.includes('--apply');
  const initial = await inspectCurrentState();
  printSummary(apply ? 'APPLY' : 'CHECK', initial);

  if (!apply) {
    console.log('WRITE_PERFORMED=NO');
    return;
  }

  await applyMappings(initial);

  const finalState = await inspectCurrentState();
  printSummary('APPLY', finalState);

  const total = await prisma.arsenCompanyMapping.count();
  console.log(`TOTAL_ARSEN_MAPPING_ROWS=${total}`);

  if (finalState.toCreate.length !== 0 || finalState.conflicts.length !== 0) {
    throw new Error('Final Arsen mapping verification failed.');
  }

  console.log('WRITE_PERFORMED=YES');
  console.log(`ARSEN_MAPPING_IMPORT_OK=${EXPECTED_MAPPING_COUNT}`);
}

main()
  .catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`ARSEN_MAPPING_IMPORT_FAILED=${message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
