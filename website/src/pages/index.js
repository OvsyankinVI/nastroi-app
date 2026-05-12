import React from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import './index.css';

export default function Home() {
  return (
    <Layout title="Настрой" description="Социальное приложение для настроя близких">
      <main className="landing">
        <section className="hero">
          <div className="heroText">
            <p className="eyebrow">iPhone · Виджеты · Apple Watch</p>
            <h1>Покажи близким, в каком ты сейчас настрое</h1>
            <p className="subtitle">
              Создай своего персонажа, настрой его состояние и поделись с друзьями или близкими.
              Они увидят, что тебе сейчас поможет, а что сегодня лучше не делать.
            </p>

            <div className="heroButtons">
              <Link className="primaryButton" to="/docs/user/overview">
                Как пользоваться
              </Link>
              <Link className="secondaryButton" to="/docs/technical/architecture">
                Документация
              </Link>
            </div>
          </div>

          <div className="heroMockup">
            <div className="realPhoneWrapper">
              <img
                src="/nastroi-app/img/app-preview.png"
                alt="Настрой приложение"
                className="realPhoneImage"
              />
            </div>
          </div>
        </section>

        <section className="section">
          <p className="eyebrow">Идея</p>
          <h2>Настрой — это социальная сеть состояний</h2>
          <p>
            Не всегда хочется объяснять словами, что с тобой происходит.
            В Настрое твой персонаж говорит за тебя: показывает настроение,
            потребности и рекомендации для близких.
          </p>
        </section>

        <section className="steps">
          <Step number="01" title="Создай персонажа" text="Настрой внешний образ и профиль, который будут видеть близкие." />
          <Step number="02" title="Выбери настрой" text="Укажи свое состояние, что помогает и чего лучше избегать." />
          <Step number="03" title="Поделись" text="Добавляй друзей через QR-код или ссылку." />
          <Step number="04" title="Следи за близкими" text="Смотри настрой друзей, партнера или семьи в приложении и виджетах." />
        </section>

        <section className="section cycle">
          <div>
            <p className="eyebrow">Цикличность</p>
            <h2>Если настрой повторяется — задай цикл</h2>
            <p>
              Для состояний, которые меняются по повторяющемуся ритму,
              можно настроить цикличность. Это помогает близким заранее понимать,
              когда лучше обсудить важное, а когда стоит просто поддержать.
            </p>
          </div>

          <div className="cycleCard">
            <span>Цикл настроя</span>
            <strong>Спокойствие → Чувствительность → Восстановление</strong>
          </div>
        </section>

        <section className="section">
          <p className="eyebrow">Документация</p>
          <h2>Вся документация внутри сайта</h2>
          <p>
            Пользовательские инструкции и техническая документация открываются как страницы сайта:
            с описаниями, схемами, архитектурой и сценариями работы.
          </p>

          <div className="docsGrid">
            <Link className="docTile" to="/docs/user/overview">
              <h3>Пользовательская документация</h3>
              <p>Как создать персонажа, поделиться им, добавить друзей и следить за настроем.</p>
            </Link>

            <Link className="docTile" to="/docs/technical/architecture">
              <h3>Техническая документация</h3>
              <p>Архитектура, сервисы, методы, виджеты, QR, ссылки и Apple Watch.</p>
            </Link>
          </div>
        </section>
      </main>
    </Layout>
  );
}

function Step({ number, title, text }) {
  return (
    <div className="step">
      <span>{number}</span>
      <h3>{title}</h3>
      <p>{text}</p>
    </div>
  );
}