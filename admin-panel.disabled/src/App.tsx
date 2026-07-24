import polyglotI18nProvider from 'ra-i18n-polyglot';
import {
  Admin,
  Resource,
  BooleanField,
  BooleanInput,
  Create,
  Datagrid,
  DateField,
  Edit,
  List,
  Login,
  NumberField,
  NumberInput,
  ReferenceField,
  ReferenceInput,
  ReferenceArrayInput,
  SelectArrayInput,
  SelectInput,
  SimpleForm,
  TextField,
  TextInput,
  FileField,
  FileInput,
  ImageField,
  ImageInput,
  required,
  FunctionField,
} from 'react-admin';
import BookIcon from '@mui/icons-material/MenuBook';
import ChapterIcon from '@mui/icons-material/Article';
import PeopleIcon from '@mui/icons-material/People';
import PaymentIcon from '@mui/icons-material/Payment';
import CardMembershipIcon from '@mui/icons-material/CardMembership';
import DescriptionIcon from '@mui/icons-material/Description';
import InfoIcon from '@mui/icons-material/Info';
import AppleIcon from '@mui/icons-material/Apple';
import SmsIcon from '@mui/icons-material/Sms';

import { dataProvider } from './dataProvider';
import { authProvider } from './authProvider';
import tgMessages from './i18n/tg';

const i18nProvider = polyglotI18nProvider(() => tgMessages as any, 'tg');

const mediaUrl = (value?: string | null) => {
  if (!value) return '';
  if (value.startsWith('http')) return value;
  return `${window.location.origin}${value}`;
};

const LoginPage = () => (
  <Login
    title={tgMessages.app.login_title}
    sx={{
      '& .RaLogin-card': { borderRadius: 2 },
    }}
  />
);

const BookList = () => (
  <List sort={{ field: 'created_at', order: 'DESC' }}>
    <Datagrid rowClick="edit">
      <TextField source="id" label="ID" />
      <TextField source="title" label="Ном" />
      <NumberField source="price" label="Нарх" />
      <DateField source="created_at" label="Сана" showTime />
    </Datagrid>
  </List>
);

const BookForm = () => (
  <SimpleForm>
    <TextInput source="title" label="Номи китоб" validate={required()} fullWidth />
    <TextInput source="description" label="Тавсиф" multiline fullWidth />
    <NumberInput source="price" label="Нарх (сомонӣ)" />
    <ImageInput source="cover_image" label="Расми муқова" accept={{ 'image/*': [] }}>
      <ImageField source="src" title="title" />
    </ImageInput>
    <FunctionField
      label="Муқова (ҳозира)"
      render={(record: { cover_image?: string }) =>
        record.cover_image ? (
          <img src={mediaUrl(record.cover_image)} alt="" style={{ maxHeight: 120 }} />
        ) : (
          '—'
        )
      }
    />
  </SimpleForm>
);

const BookEdit = () => (
  <Edit>
    <BookForm />
  </Edit>
);

const BookCreate = () => (
  <Create>
    <BookForm />
  </Create>
);

const ChapterList = () => (
  <List sort={{ field: 'order', order: 'ASC' }}>
    <Datagrid rowClick="edit">
      <TextField source="id" label="ID" />
      <ReferenceField source="book" reference="books" label="Китоб">
        <TextField source="title" />
      </ReferenceField>
      <TextField source="title" label="Сарлавҳа" />
      <NumberField source="order" label="Тартиб" />
      <BooleanField source="is_free" label="Ройгон" />
      <BooleanField source="is_premium" label="Премиум" />
    </Datagrid>
  </List>
);

const ChapterForm = () => (
  <SimpleForm>
    <ReferenceInput source="book" reference="books" label="Китоб">
      <SelectInput optionText="title" validate={required()} />
    </ReferenceInput>
    <TextInput source="title" label="Сарлавҳа" validate={required()} fullWidth />
    <NumberInput source="order" label="Тартиб" defaultValue={1} />
    <BooleanInput source="is_free" label="Ройгон" />
    <BooleanInput source="is_premium" label="Премиум" />
    <TextInput source="content" label="Матн (HTML)" multiline fullWidth sx={{ '& textarea': { minHeight: 280 } }} />
  </SimpleForm>
);

const ChapterEdit = () => (
  <Edit>
    <ChapterForm />
  </Edit>
);

const ChapterCreate = () => (
  <Create>
    <ChapterForm />
  </Create>
);

const UserList = () => (
  <List sort={{ field: 'date_joined', order: 'DESC' }}>
    <Datagrid rowClick="edit">
      <TextField source="id" label="ID" />
      <TextField source="phone" label="Телефон" />
      <TextField source="telegram_username" label="Telegram" />
      <NumberField source="balance" label="Баланс" />
      <BooleanField source="is_staff" label="Админ" />
      <DateField source="date_joined" label="Сана" showTime />
    </Datagrid>
  </List>
);

const UserForm = () => (
  <SimpleForm>
    <TextInput source="phone" label="Телефон" fullWidth />
    <TextInput source="password" label="Пароли нав" type="password" fullWidth />
    <TextInput source="telegram_id" label="Telegram ID" fullWidth />
    <TextInput source="telegram_username" label="@username" fullWidth />
    <TextInput source="first_name" label="Ном" fullWidth />
    <TextInput source="last_name" label="Насаб" fullWidth />
    <NumberInput source="balance" label="Баланс" />
    <BooleanInput source="is_active" label="Фаъол" />
    <BooleanInput source="is_staff" label="Дастрасии админ" />
    <BooleanInput source="is_superuser" label="Superuser" />
  </SimpleForm>
);

const UserEdit = () => (
  <Edit>
    <UserForm />
  </Edit>
);

const UserCreate = () => (
  <Create>
    <UserForm />
  </Create>
);

const TransactionList = () => (
  <List sort={{ field: 'created_at', order: 'DESC' }}>
    <Datagrid rowClick="edit">
      <TextField source="transaction_id" label="ID" />
      <TextField source="user_phone" label="Корбар" />
      <NumberField source="amount" label="Маблағ" />
      <TextField source="status" label="Ҳолат" />
      <TextField source="payment_provider" label="Провайдер" />
      <DateField source="created_at" label="Сана" showTime />
    </Datagrid>
  </List>
);

const TransactionForm = () => (
  <SimpleForm>
    <TextInput source="transaction_id" label="ID" fullWidth />
    <ReferenceInput source="user" reference="users" label="Корбар">
      <SelectInput optionText="phone" />
    </ReferenceInput>
    <NumberInput source="amount" label="Маблағ" />
    <SelectInput
      source="status"
      label="Ҳолат"
      choices={[
        { id: 'PENDING', name: 'Интизор' },
        { id: 'SUCCESS', name: 'Муваффақ' },
        { id: 'FAILED', name: 'Ноком' },
      ]}
    />
    <TextInput source="description" label="Тавсиф" fullWidth />
    <TextInput source="payment_provider" label="Провайдер" fullWidth />
  </SimpleForm>
);

const TransactionEdit = () => (
  <Edit>
    <TransactionForm />
  </Edit>
);

const TransactionCreate = () => (
  <Create>
    <TransactionForm />
  </Create>
);

const PlanList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="name" label="Ном" />
      <ReferenceField source="book" reference="books" label="Китоб">
        <TextField source="title" />
      </ReferenceField>
      <NumberField source="price" label="Нарх" />
      <NumberField source="days" label="Рӯз" />
      <BooleanField source="is_active" label="Фаъол" />
    </Datagrid>
  </List>
);

const PlanForm = () => (
  <SimpleForm>
    <ReferenceInput source="book" reference="books" label="Китоб">
      <SelectInput optionText="title" validate={required()} />
    </ReferenceInput>
    <TextInput source="name" label="Ном" validate={required()} fullWidth />
    <NumberInput source="price" label="Нарх" />
    <NumberInput source="days" label="Рӯзҳо" />
    <BooleanInput source="is_active" label="Фаъол" />
    <TextInput source="apple_product_id" label="Apple Product ID" fullWidth />
    <ReferenceArrayInput source="chapter_ids" reference="chapters" label="Бобҳо">
      <SelectArrayInput optionText="title" />
    </ReferenceArrayInput>
  </SimpleForm>
);

const PlanEdit = () => (
  <Edit>
    <PlanForm />
  </Edit>
);

const PlanCreate = () => (
  <Create>
    <PlanForm />
  </Create>
);

const LegalList = () => (
  <List sort={{ field: 'order', order: 'ASC' }}>
    <Datagrid rowClick="edit">
      <NumberField source="order" label="№" />
      <TextField source="title" label="Сарлавҳа" />
      <BooleanField source="is_active" label="Фаъол" />
      <BooleanField source="has_pdf" label="PDF" />
    </Datagrid>
  </List>
);

const LegalForm = () => (
  <SimpleForm>
    <NumberInput source="order" label="№" />
    <TextInput source="title" label="Сарлавҳа" validate={required()} fullWidth />
    <FileInput source="pdf_file" label="PDF файл" accept={{ 'application/pdf': ['.pdf'] }}>
      <FileField source="src" title="title" />
    </FileInput>
    <TextInput source="pdf_url" label="URL-и PDF" fullWidth />
    <BooleanInput source="is_active" label="Фаъол" />
  </SimpleForm>
);

const LegalEdit = () => (
  <Edit>
    <LegalForm />
  </Edit>
);

const LegalCreate = () => (
  <Create>
    <LegalForm />
  </Create>
);

const AboutList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="title" label="Сарлавҳа" />
      <DateField source="updated_at" label="Навсозӣ" showTime />
    </Datagrid>
  </List>
);

const AboutForm = () => (
  <SimpleForm>
    <TextInput source="title" label="Сарлавҳа" fullWidth />
    <TextInput source="content" label="Матн" multiline fullWidth sx={{ '& textarea': { minHeight: 200 } }} />
    <TextInput source="phone" label="Телефон" fullWidth />
    <TextInput source="email" label="Email" fullWidth />
    <TextInput source="telegram_url" label="Telegram" fullWidth />
    <TextInput source="whatsapp_url" label="WhatsApp" fullWidth />
  </SimpleForm>
);

const AboutEdit = () => (
  <Edit>
    <AboutForm />
  </Edit>
);

const AboutCreate = () => (
  <Create>
    <AboutForm />
  </Create>
);

const SubscriptionList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="user_phone" label="Корбар" />
      <TextField source="plan_name" label="Нақша" />
      <DateField source="purchased_at" label="Харид" showTime />
      <DateField source="expires_at" label="Анҷом" showTime />
    </Datagrid>
  </List>
);

const SubscriptionForm = () => (
  <SimpleForm>
    <ReferenceInput source="user" reference="users" label="Корбар">
      <SelectInput optionText="phone" />
    </ReferenceInput>
    <ReferenceInput source="plan" reference="subscription-plans" label="Нақша">
      <SelectInput optionText="name" />
    </ReferenceInput>
    <TextInput source="expires_at" label="Муҳлат (ISO)" fullWidth />
  </SimpleForm>
);

const SubscriptionEdit = () => (
  <Edit>
    <SubscriptionForm />
  </Edit>
);

const SubscriptionCreate = () => (
  <Create>
    <SubscriptionForm />
  </Create>
);

const PurchaseList = () => (
  <List>
    <Datagrid>
      <TextField source="user_phone" label="Корбар" />
      <TextField source="book_title" label="Китоб" />
      <DateField source="purchased_at" label="Сана" showTime />
    </Datagrid>
  </List>
);

const PurchasedChapterList = () => (
  <List>
    <Datagrid>
      <TextField source="user_phone" label="Корбар" />
      <TextField source="chapter_title" label="Боб" />
      <NumberField source="price_paid" label="Нарх" />
      <DateField source="purchased_at" label="Сана" showTime />
    </Datagrid>
  </List>
);

const AppleList = () => (
  <List>
    <Datagrid>
      <TextField source="transaction_id" label="ID" />
      <TextField source="user_phone" label="Корбар" />
      <TextField source="product_id" label="Product" />
      <DateField source="created_at" label="Сана" showTime />
    </Datagrid>
  </List>
);

const OtpList = () => (
  <List>
    <Datagrid>
      <TextField source="phone" label="Телефон" />
      <TextField source="code" label="Код" />
      <DateField source="updated_at" label="Навсозӣ" showTime />
    </Datagrid>
  </List>
);

export default function App() {
  return (
    <Admin
      title={tgMessages.app.title}
      dataProvider={dataProvider}
      authProvider={authProvider}
      i18nProvider={i18nProvider}
      loginPage={LoginPage}
      requireAuth
    >
      <Resource
        name="books"
        list={BookList}
        edit={BookEdit}
        create={BookCreate}
        recordRepresentation="title"
        icon={BookIcon}
        options={{ label: 'Китобҳо' }}
      />

      <Resource
        name="chapters"
        list={ChapterList}
        edit={ChapterEdit}
        create={ChapterCreate}
        recordRepresentation="title"
        icon={ChapterIcon}
        options={{ label: 'Бобҳо' }}
      />

      <Resource
        name="users"
        list={UserList}
        edit={UserEdit}
        create={UserCreate}
        recordRepresentation="phone"
        icon={PeopleIcon}
        options={{ label: 'Корбарон' }}
      />

      <Resource
        name="transactions"
        list={TransactionList}
        edit={TransactionEdit}
        create={TransactionCreate}
        recordRepresentation="transaction_id"
        icon={PaymentIcon}
        options={{ label: 'Транзаксияҳо' }}
      />

      <Resource
        name="subscription-plans"
        list={PlanList}
        edit={PlanEdit}
        create={PlanCreate}
        recordRepresentation="name"
        icon={CardMembershipIcon}
        options={{ label: 'Нақшаҳои обуна' }}
      />

      <Resource
        name="subscriptions"
        list={SubscriptionList}
        edit={SubscriptionEdit}
        create={SubscriptionCreate}
        icon={CardMembershipIcon}
        options={{ label: 'Обунаҳо' }}
      />

      <Resource
        name="purchases"
        list={PurchaseList}
        icon={BookIcon}
        options={{ label: 'Харидҳои китоб' }}
      />

      <Resource
        name="purchased-chapters"
        list={PurchasedChapterList}
        icon={ChapterIcon}
        options={{ label: 'Бобҳои харидашуда' }}
      />

      <Resource
        name="legal-documents"
        list={LegalList}
        edit={LegalEdit}
        create={LegalCreate}
        recordRepresentation="title"
        icon={DescriptionIcon}
        options={{ label: 'Санадҳои ҳуқуқӣ' }}
      />

      <Resource
        name="about-pages"
        list={AboutList}
        edit={AboutEdit}
        create={AboutCreate}
        icon={InfoIcon}
        options={{ label: 'Дар бораи мо' }}
      />

      <Resource
        name="apple-transactions"
        list={AppleList}
        icon={AppleIcon}
        options={{ label: 'Apple IAP' }}
      />

      <Resource
        name="phone-otp"
        list={OtpList}
        icon={SmsIcon}
        options={{ label: 'OTP' }}
      />
    </Admin>
  );
}
