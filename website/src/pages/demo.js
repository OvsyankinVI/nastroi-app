import React from 'react';
import Layout from '@theme/Layout';
import useBaseUrl from '@docusaurus/useBaseUrl';
import './demo.css';

export default function Demo() {
  const demoUrl = useBaseUrl('/demo_app/index.html');

  return (
    <Layout
      title="Демо"
      description="Демо-версия приложения Настрой"
    >
      <main className="demoPage">
        <section className="demoHeader">
          <p className="demoEyebrow">Демо приложения</p>

          <h1>
            Попробуй Настрой прямо в браузере
          </h1>

          <p>
            Это web-версия приложения. Виджеты iPhone,
            Apple Watch и нативные iOS-возможности в браузере
            могут быть недоступны.
          </p>
        </section>

        <section className="demoFrameSection">
          <div className="iphoneShell">
            <div className="dynamicIsland" />

            <iframe
              src={demoUrl}
              title="Настрой demo"
              className="flutterDemoFrame"
            />
          </div>
        </section>
      </main>
    </Layout>
  );
}