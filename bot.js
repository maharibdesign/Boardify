require('dotenv').config();
const TelegramBot = require('node-telegram-bot-api');

const token = process.env.TELEGRAM_BOT_TOKEN;
const webAppUrl = process.env.VERCEL_URL; // Your Vercel URL

if (!token || !webAppUrl) {
    console.error("Bot token and web app URL must be provided in .env");
    process.exit(1);
}

const bot = new TelegramBot(token, { polling: true });

bot.onText(/\/start/, (msg) => {
  const chatId = msg.chat.id;
  
  bot.sendMessage(chatId, 'Welcome to Boardify! Click the button below to open your task boards.', {
    reply_markup: {
      // Use an inline keyboard for a button within the chat
      inline_keyboard: [
        [{ text: '🚀 Open Boardify', web_app: { url: webAppUrl } }]
      ]
    }
  });
});

console.log('Boardify Telegram bot is running...');