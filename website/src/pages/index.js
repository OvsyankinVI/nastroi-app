import React from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Layout from '@theme/Layout';
import './index.css';

export default function Home() {
  return (
    <Layout title="Настрой" description="Социальное приложение для настроя близких">
      <main className="landing">
        <section className="hero">
          <div className="heroText">
            <p className="eyebrow">iPhone · Виджеты · Apple Watch</p>

            <h1>Близкие поймут тебя без лишних слов</h1>

            <p className="subtitle">
              Иногда сложно объяснить, что ты чувствуешь.
              Настрой помогает близким понять,
              как тебя поддержать именно сегодня.
            </p>

            <div className="heroButtons">
              <Link className="primaryButton" to="/docs/user/overview">
                Как пользоваться
              </Link>

              <Link className="secondaryButton" to="/docs/technical/architecture">
                Как это работает
              </Link>
            </div>
          </div>

          <div className="heroMockup">
            <div className="demoWrapper">
              <iframe
                src={useBaseUrl('/demo_app/index.html')}
                title="Настрой demo"
                className="demoFrame"
              />
            </div>
          </div>
        </section>

        <section className="section">
          <p className="eyebrow">Идея</p>

          <h2>
            Меньше недопонимания.
            Больше заботы.
          </h2>

          <p>
            У каждого бывают дни, когда хочется тишины,
            поддержки или просто, чтобы тебя не трогали.
          </p>

          <p>
            Настрой помогает близким увидеть твое состояние
            и понять, что тебе сейчас действительно нужно.
          </p>
        </section>

        <section className="steps">
          <Step
            number="01"
            title="Создай своего персонажа"
            text="Сделай аватар, который отражает именно тебя."
          />

          <Step
            number="02"
            title="Поделись своим состоянием"
            text="Покажи, что ты чувствуешь прямо сейчас."
          />

          <Step
            number="03"
            title="Пригласи близких"
            text="Через QR-код или ссылку. Буквально за секунду."
          />

          <Step
            number="04"
            title="Будьте ближе"
            text="Понимай настроение друзей, партнера и семьи."
          />
        </section>

        <section className="section widgetsSection">
          <p className="eyebrow">Всегда рядом</p>

          <h2>
            Настрой близких всегда перед глазами
          </h2>

          <p>
            Добавь виджет на экран iPhone и в Apple Watch —
            чтобы в любой момент понимать, как чувствуют себя
            важные для тебя люди.
          </p>

          <div className="widgetsGrid">
            <div className="widgetCard">
              <img
                src={useBaseUrl('/img/iphone-widget.png')}
                alt="iPhone widget"
                className="widgetImage"
              />

              <h3>Виджет iPhone</h3>

              <p>
                Видишь состояние близкого прямо на рабочем столе телефона.
              </p>
            </div>

            <div className="widgetCard">
              <img
                src={useBaseUrl('/img/watch-widget.png')}
                alt="Apple Watch widget"
                className="widgetImage"
              />

              <h3>Apple Watch</h3>

              <p>
                Проверяй настрой друзей прямо с часов и открывай приложение
                для полного списка.
              </p>
            </div>
          </div>
        </section>

        <section className="section cycle">
          <div>
            <p className="eyebrow">Цикличность</p>

            <h2>
              Если твое состояние меняется циклично —
              приложение это запомнит
            </h2>

            <p>
              Настрой может учитывать повторяющиеся эмоциональные циклы,
              чтобы близкие лучше чувствовали твой ритм и выбирали
              правильный момент для важных разговоров.
            </p>
          </div>

          <div className="cycleCard">
            <span>Цикл настроя</span>
            <strong>
              Спокойствие → Чувствительность → Восстановление
            </strong>
          </div>
        </section>

        <section className="section">
          <p className="eyebrow">Документация</p>

          <h2>
            Прозрачный продукт. Всё открыто.
          </h2>

          <p>
            Мы подробно показали, как работает приложение:
            пользовательские сценарии, техническую архитектуру
            и внутреннюю логику продукта.
          </p>

          <div className="docsGrid">
            <Link className="docTile" to="/docs/user/overview">
              <h3>Пользовательская документация</h3>
              <p>
                Как создать персонажа, поделиться им,
                добавить друзей и следить за настроем.
              </p>
            </Link>

            <Link className="docTile" to="/docs/technical/architecture">
              <h3>Техническая документация</h3>
              <p>
                Архитектура, сервисы, методы, виджеты,
                QR, ссылки и Apple Watch.
              </p>
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