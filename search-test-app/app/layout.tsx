import './globals.css'

export const metadata = {
  title: 'Search Test App',
  description: 'Testing Foss SA search functionality',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        {children}
      </body>
    </html>
  )
}
